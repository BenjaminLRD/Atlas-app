import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/ai/vision/ai_vision_service.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';
import 'package:atlas/services/food/off_search_client.dart';
import 'package:atlas/services/food/product_lookup_service.dart';
import 'package:atlas/services/food/product_matcher.dart';

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

class _FakeVision extends AIVisionService {
  @override
  Future<ImagePickResult> pickWithOutcome({
    required ImageSource source,
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async => const ImagePickResult.picked(_photo);
}

class _FakeLookup extends ProductLookupService {
  _FakeLookup(this.result, {this.gate});

  final ProductLookupResult result;
  final Completer<void>? gate;
  ProductCandidate? asked;
  int calls = 0;

  @override
  Future<ProductLookupResult> lookup(ProductCandidate candidate) async {
    calls++;
    asked = candidate;
    await gate?.future;
    return result;
  }
}

List<OffProduct> _products() {
  final json = jsonDecode(
    File('test/fixtures/off_search_mountain_dew_india.json').readAsStringSync(),
  );
  return [
    for (final hit in json['hits'] as List)
      ?OffProduct.fromSearchHit(Map<String, dynamic>.from(hit as Map)),
  ];
}

OffProduct _p(String code) => _products().firstWhere((p) => p.code == code);

/// The 250 ml, 400 ml and 750 ml Mountain Dew records of the real fixture.
final _dew250 = _p('8902080364022');
final _dew400 = _p('8902080364589');
final _dew750 = _p('8902080364053'); // listed, but without nutrition

/// What the model said for the bottle in the bug report: a wrong size and
/// invented numbers, which must never be shown as facts.
String _answer({
  Map<String, dynamic> override = const {},
  List<String> remove = const [],
}) {
  final estimate = <String, dynamic>{
    'is_food': true,
    'foodName': 'Mountain Dew',
    'brand': 'PepsiCo',
    'isPackagedProduct': true,
    'packageSize': 750,
    'packageUnit': 'ml',
    'servingSize': 600,
    'servingUnit': 'ml',
    'calories': 287,
    'protein': 0,
    'carbohydrates': 78,
    'fats': 0,
    'confidence': 0.9,
    ...override,
  };
  for (final key in remove) {
    estimate.remove(key);
  }
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': jsonEncode(estimate)},
          ],
        },
      },
    ],
  });
}

String _homeFood() => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {
            'text': jsonEncode({
              'is_food': true,
              'foodName': 'Rice and dal',
              'servingSize': 350,
              'servingUnit': 'g',
              'calories': 480,
              'protein': 14,
              'carbohydrates': 80,
              'fats': 9,
              'confidence': 0.7,
            }),
          },
        ],
      },
    },
  ],
});

Future<void> _scan(
  WidgetTester tester, {
  required ProductLookupService lookup,
  String? body,
  Size size = const Size(900, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  ProductLookupService.setInstance(lookup);
  FoodAIVisionService.setInstance(
    FoodAIVisionService(
      config: AIConfig(
        proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
        accessTokenProvider: () => 'user-token',
      ),
      httpClient: MockClient(
        (_) async => http.Response(body ?? _answer(), 200),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UnifiedFoodScannerScreen(
                    initialMode: UnifiedScanMode.foodAi,
                    visionService: _FakeVision(),
                    currentMealId: 'Lunch',
                    currentMealTitle: 'Lunch',
                  ),
                ),
              ),
              child: const Text('open scanner'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open scanner'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Take Photo'));
  await tester.pumpAndSettle();
}

String _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('ai_estimate_label'))).data!;

Iterable<ConsumedFood> _logged() => FitnessProvider
    .instance
    .todayNutritionLog
    .meals
    .expand((m) => m.consumedFoods);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(() {
    FoodAIVisionService.resetInstance();
    ProductLookupService.resetInstance();
  });

  group('what is asked', () {
    testWidgets('the model\'s brand, name and printed size are searched', (
      tester,
    ) async {
      final lookup = _FakeLookup(const ProductLookupResult.none());
      await _scan(tester, lookup: lookup);

      expect(lookup.calls, 1);
      expect(lookup.asked!.name, 'Mountain Dew');
      expect(lookup.asked!.brand, 'PepsiCo');
      expect(lookup.asked!.sizeValue, 750);
      expect(lookup.asked!.sizeUnit, 'ml');
    });

    testWidgets('home food is not looked up', (tester) async {
      final lookup = _FakeLookup(const ProductLookupResult.none());
      await _scan(tester, lookup: lookup, body: _homeFood());

      expect(lookup.calls, 0);
      expect(find.text('Portion: ~350 g'), findsOneWidget);
      expect(_label(tester), 'Unverified AI estimate');
    });

    testWidgets('the screen says it is looking while it waits', (tester) async {
      final gate = Completer<void>();
      final lookup = _FakeLookup(const ProductLookupResult.none(), gate: gate);
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ProductLookupService.setInstance(lookup);
      FoodAIVisionService.setInstance(
        FoodAIVisionService(
          config: AIConfig(
            proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
            accessTokenProvider: () => 'user-token',
          ),
          httpClient: MockClient((_) async => http.Response(_answer(), 200)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedFoodScannerScreen(
            initialMode: UnifiedScanMode.foodAi,
            visionService: _FakeVision(),
            currentMealId: 'Lunch',
            currentMealTitle: 'Lunch',
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Looking up the product'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Looking up the product'), findsNothing);
    });
  });

  group('an exact database match', () {
    testWidgets('shows database values, not the AI guess', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      expect(_label(tester), 'Product database');
      expect(find.text('PRODUCT MATCH'), findsOneWidget);
      expect(find.text('AI FOOD ESTIMATE'), findsNothing);
      // 400 ml at 49 kcal and 12.3 g carbs per 100 ml.
      expect(find.text('Portion: 400 ml'), findsOneWidget);
      expect(find.text('196 kcal'), findsOneWidget);
      expect(find.text('49.2g'), findsOneWidget);
      // The database says protein and fat are really 0: a verified zero.
      expect(find.text('0.0g'), findsNWidgets(2));
      // None of the AI's numbers, none of its "approximately".
      expect(find.textContaining('287'), findsNothing);
      expect(find.textContaining('~'), findsNothing);
      expect(find.byKey(const Key('ai_estimate_disclaimer')), findsNothing);
    });

    testWidgets('credits Open Food Facts and links to the product', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      final note = tester
          .widget<Text>(find.byKey(const Key('product_source_note')))
          .data!;
      expect(note, contains('Open Food Facts'));
      expect(note, contains('8902080364589'));
    });

    testWidgets('logs the database food with its source and basis', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();

      final entry = _logged().single;
      expect(entry.unit, 'ml');
      expect(entry.quantity, 400);
      expect(entry.calories, closeTo(196, 0.01));
      expect(entry.food.nutritionSource, NutritionSource.openFoodFacts);
      expect(entry.food.sourceUrl, contains('8902080364589'));
      expect(entry.food.nutritionBasis, NutritionBasis.per100ml);
      expect(entry.caloriesKnown, isTrue);
    });

    testWidgets('the size can still be edited', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Portion Size (ml)'),
        '200',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Portion: 200 ml'), findsOneWidget);
      expect(find.text('98 kcal'), findsOneWidget);
      // Only the portion changed, so it is still the database's data.
      expect(_label(tester), 'Product database');
    });

    testWidgets('typing different values makes them yours', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'),
        '150',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(_label(tester), 'Edited by you');
      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      expect(_logged().single.food.nutritionSource, NutritionSource.userEntry);
    });
  });

  group('the 750 ml bottle', () {
    testWidgets('an exact listing without nutrition shows unknown, not zero', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(
          ProductLookupResult.exact(_dew750, candidates: [_dew250, _dew400]),
        ),
      );

      expect(_label(tester), 'Product database • no nutrition');
      expect(find.text('Portion: 750 ml'), findsOneWidget);
      expect(find.text('— kcal'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));
      expect(
        find.byKey(const Key('product_no_nutrition_note')),
        findsOneWidget,
      );
      expect(find.textContaining('287'), findsNothing);
      expect(find.textContaining('600'), findsNothing);
    });

    testWidgets('other sizes with data are offered, not merged in', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(
          ProductLookupResult.exact(_dew750, candidates: [_dew250, _dew400]),
        ),
      );

      expect(find.text('Same product, other sizes'), findsOneWidget);
      expect(
        find.byKey(Key('product_candidate_${_dew250.code}')),
        findsOneWidget,
      );
      // The card itself still shows no values.
      expect(find.text('— kcal'), findsOneWidget);
    });

    testWidgets('logging it without calories asks first', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew750)),
      );

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      expect(find.text('Calories unknown'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_logged(), isEmpty);
    });

    testWidgets('choosing a size and confirming 750 ml scales per 100 ml', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(
          ProductLookupResult.choose([_dew250, _dew400, _dew750]),
        ),
        body: _answer(remove: ['packageSize', 'packageUnit']),
      );

      expect(find.text('Which product is this?'), findsOneWidget);
      await tester.tap(find.byKey(Key('product_candidate_${_dew250.code}')));
      await tester.pumpAndSettle();

      // The listing's 250 ml is a starting point, not the user's bottle.
      expect(_label(tester), 'Database match you chose');
      expect(find.textContaining('250 ml • not confirmed'), findsOneWidget);
      expect(find.byKey(const Key('lookup_note')), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm package size'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Portion Size (ml)'),
        '750',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Portion: 750 ml'), findsOneWidget);
      // 49 kcal per 100 ml x 7.5.
      expect(find.text('368 kcal'), findsOneWidget);

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      final entry = _logged().single;
      expect(entry.quantity, 750);
      expect(entry.unit, 'ml');
      expect(entry.calories, closeTo(367.5, 0.01));
    });
  });

  group('several plausible products', () {
    testWidgets('are listed with their size and whether data exists', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(
          ProductLookupResult.choose([_dew250, _dew400, _dew750]),
        ),
      );

      expect(find.text('Which product is this?'), findsOneWidget);
      expect(find.textContaining('250 ml'), findsWidgets);
      expect(find.textContaining('no nutrition data'), findsOneWidget);
      expect(find.textContaining('49 kcal'), findsWidgets);
      // Nothing is picked for the user: no estimate card yet.
      expect(find.text('PRODUCT MATCH'), findsNothing);
      expect(find.textContaining('Add To'), findsNothing);
    });

    testWidgets('"none of these" falls back to the unverified estimate', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.choose([_dew250, _dew400])),
      );

      await tester.tap(find.byKey(const Key('product_candidates_dismiss')));
      await tester.pumpAndSettle();

      expect(find.text('AI FOOD ESTIMATE'), findsOneWidget);
      expect(_label(tester), 'Unverified AI estimate');
      expect(find.text('Which product is this?'), findsNothing);
    });

    testWidgets('a product not listed for India says so', (tester) async {
      final abroad = OffProduct.forTest(
        code: '5449000000996',
        food: _dew400.food,
        brands: const ['PepsiCo'],
        countries: const ['en:united-states'],
        sizeValue: 400,
        sizeUnit: 'ml',
      );
      await _scan(
        tester,
        lookup: _FakeLookup(
          ProductLookupResult.choose([abroad], widened: true),
        ),
      );

      expect(find.textContaining('Not listed for India'), findsOneWidget);
    });
  });

  group('no reliable match', () {
    testWidgets('keeps the AI result as an unverified estimate', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(const ProductLookupResult.none()),
      );

      expect(_label(tester), 'Unverified AI estimate');
      expect(find.text('AI FOOD ESTIMATE'), findsOneWidget);
      expect(find.byKey(const Key('lookup_note')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('lookup_note'))).data,
        contains('No matching product'),
      );
    });

    testWidgets('the 600 ml guess is not presented as fact', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(const ProductLookupResult.none()),
      );

      expect(find.textContaining('~600 ml • not confirmed'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('AI zeros for protein and fat are dashes, not ~0.0 g', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(const ProductLookupResult.none()),
      );

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('~0.0g'), findsNothing);
      expect(find.text('~78.0g'), findsOneWidget);
      expect(find.text('~287 kcal'), findsOneWidget);
    });

    testWidgets('the size must be confirmed before it is logged', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(const ProductLookupResult.none()),
      );

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm package size'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_logged(), isEmpty);

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Portion Size (ml)'),
        '750',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Confirmed: the number is the user's now, and logging is open.
      expect(find.text('Portion: ~750 ml'), findsOneWidget);
      expect(find.textContaining('not confirmed'), findsNothing);
      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      expect(_logged().single.quantity, 750);
    });

    testWidgets('manual editing stays available', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(const ProductLookupResult.none()),
      );

      expect(find.text('Edit Details'), findsOneWidget);
      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();
      expect(find.text('Edit AI Food Estimate'), findsOneWidget);
      // Unknown values are blank fields, not zeros.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Protein (g)'))
            .controller!
            .text,
        isEmpty,
      );
    });
  });

  group('the database is unreachable', () {
    testWidgets('says why and keeps the estimate', (tester) async {
      await _scan(
        tester,
        lookup: _FakeLookup(
          const ProductLookupResult.failed(
            LookupFailureKind.timeout,
            'The product database took too long to answer.',
          ),
        ),
      );

      final note = tester
          .widget<Text>(find.byKey(const Key('lookup_note')))
          .data!;
      expect(note, contains('took too long'));
      expect(note, contains('AI estimate'));
      expect(_label(tester), 'Unverified AI estimate');
      expect(find.textContaining('Add To'), findsOneWidget);
    });
  });

  group('small phone', () {
    testWidgets('the result and the choice list fit 360 x 640', (tester) async {
      await _scan(
        tester,
        size: const Size(360, 640),
        lookup: _FakeLookup(
          ProductLookupResult.choose([_dew250, _dew400, _dew750]),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(Key('product_candidate_${_dew400.code}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('where the numbers came from is kept', () {
    testWidgets('an exact match is logged with how and when it was found', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );
      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();

      final food = _logged().single.food;
      expect(food.sourceMatch, SourceMatch.exactProduct);
      expect(food.sourceRetrievedAt, isNotNull);
      expect(food.nutritionSource, NutritionSource.openFoodFacts);
    });

    testWidgets('a product you picked is logged as picked by you', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.choose([_dew250, _dew400])),
      );
      await tester.tap(find.byKey(Key('product_candidate_${_dew400.code}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();

      expect(_logged().single.food.sourceMatch, SourceMatch.userSelected);
    });

    testWidgets(
      'a barcode read from the photo says so, and is logged as such',
      (tester) async {
        await _scan(
          tester,
          lookup: _FakeLookup(
            ProductLookupResult.exact(_dew400, viaBarcode: true),
          ),
          body: _answer(override: {'packageSize': 400}),
        );

        expect(
          tester.widget<Text>(find.byKey(const Key('lookup_note'))).data,
          contains('barcode the AI read'),
        );
        await tester.tap(find.textContaining('Add To'));
        await tester.pumpAndSettle();
        expect(_logged().single.food.sourceMatch, SourceMatch.barcode);
      },
    );

    testWidgets('the source note is honest about community data', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );

      final note = tester
          .widget<Text>(find.byKey(const Key('product_source_note')))
          .data!;
      expect(note, contains('Community-contributed'));
      expect(note, contains('incomplete or inaccurate'));
      expect(note, contains('retrieved 20'));
      expect(note.toLowerCase(), isNot(contains('verified')));
    });

    testWidgets('nothing on screen calls a database record verified', (
      tester,
    ) async {
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(_dew400)),
        body: _answer(override: {'packageSize': 400}),
      );
      expect(
        find.textContaining(RegExp('verified', caseSensitive: false)),
        findsNothing,
      );
    });
  });

  group('values for one serving', () {
    final perServing = OffProduct.forTest(
      code: '8901111111111',
      food: const FoodItem(
        id: 'scanned_8901111111111',
        name: 'Mountain Dew Sachet',
        brand: 'PepsiCo',
        calories: 150,
        protein: 0,
        carbohydrates: 37,
        fats: 0,
        isPackaged: true,
        barcode: '8901111111111',
        nutritionBasis: NutritionBasis.perServing,
        nutritionSource: NutritionSource.openFoodFacts,
        servingQuantity: 30,
        servingQuantityUnit: 'g',
      ),
      brands: const ['PepsiCo'],
      countries: const ['en:india'],
    );

    testWidgets(
      'start at one serving, say how big it is, and need confirming',
      (tester) async {
        await _scan(
          tester,
          lookup: _FakeLookup(ProductLookupResult.choose([perServing])),
        );
        await tester.tap(
          find.byKey(Key('product_candidate_${perServing.code}')),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('1 serving (1 serving = 30 g)'),
          findsOneWidget,
        );
        expect(find.textContaining('not confirmed'), findsOneWidget);
        expect(find.text('150 kcal'), findsOneWidget);
      },
    );

    testWidgets(
      'two servings are twice the values and are logged as servings',
      (tester) async {
        await _scan(
          tester,
          lookup: _FakeLookup(ProductLookupResult.choose([perServing])),
        );
        await tester.tap(
          find.byKey(Key('product_candidate_${perServing.code}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Portion Size (serving)'),
          '2',
        );
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(find.text('300 kcal'), findsOneWidget);
        await tester.tap(find.textContaining('Add To'));
        await tester.pumpAndSettle();

        final entry = _logged().single;
        expect(entry.unit, 'serving');
        expect(entry.quantity, 2);
        expect(entry.calories, closeTo(300, 1e-9));
        expect(entry.food.nutritionBasis, NutritionBasis.perServing);
      },
    );

    testWidgets('a whole package starts as one package', (tester) async {
      final perPackage = OffProduct.forTest(
        code: '8902222222222',
        food: const FoodItem(
          id: 'scanned_8902222222222',
          name: 'Mountain Dew Can',
          brand: 'PepsiCo',
          calories: 160,
          isPackaged: true,
          barcode: '8902222222222',
          nutritionBasis: NutritionBasis.perPackage,
          nutritionSource: NutritionSource.openFoodFacts,
          unknownNutrients: {
            FoodItem.proteinKey,
            FoodItem.carbohydrateKey,
            FoodItem.fatKey,
          },
          packageQuantity: 330,
          packageQuantityUnit: 'ml',
        ),
        brands: const ['PepsiCo'],
        countries: const ['en:india'],
        sizeValue: 330,
        sizeUnit: 'ml',
      );
      await _scan(
        tester,
        lookup: _FakeLookup(ProductLookupResult.exact(perPackage)),
      );

      expect(
        find.textContaining('1 package (package = 330 ml)'),
        findsOneWidget,
      );
      expect(find.text('160 kcal'), findsOneWidget);
      // Only calories are given; the rest are dashes, not zeros.
      expect(find.text('—'), findsNWidgets(3));
    });
  });
}
