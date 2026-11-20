import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/barcode/barcode_scanner_service.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/nutrition/barcode_food_service.dart';
import 'package:atlas/widgets/nutrition/custom_food_modal.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

const FoodItem _known = FoodItem(
  id: 'scanned_1',
  name: 'Granola Bar',
  brand: 'Acme',
  calories: 190,
  protein: 4,
  carbohydrates: 29,
  fats: 7,
  isPackaged: true,
  barcode: '1',
);

const FoodItem _unavailable = FoodItem(
  id: 'scanned_8902433040207',
  name: 'Boomer Bubble Gum',
  brand: "Wrigley's",
  calories: 0,
  protein: 0,
  carbohydrates: 0,
  fats: 0,
  isPackaged: true,
  barcode: '8902433040207',
  unknownNutrients: FoodItem.coreNutrients,
);

const FoodItem _partial = FoodItem(
  id: 'scanned_2',
  name: 'Mystery Snack',
  calories: 120,
  protein: 3,
  carbohydrates: 0,
  fats: 0,
  isPackaged: true,
  barcode: '2',
  unknownNutrients: {FoodItem.carbohydrateKey, FoodItem.fatKey},
);

const FoodItem _noCalories = FoodItem(
  id: 'scanned_3',
  name: 'Protein Pudding',
  calories: 0,
  protein: 10,
  carbohydrates: 5,
  fats: 2,
  isPackaged: true,
  barcode: '3',
  unknownNutrients: {FoodItem.calorieKey},
);

Future<void> _bigScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens the result card the way the scanner does.
Future<void> _openCard(WidgetTester tester, FoodItem food) async {
  await _bigScreen(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => ScannedFoodResultCard.show(context, food: food),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _ScriptedLookup implements BarcodeFoodService {
  _ScriptedLookup(this.script);

  /// Each call takes the next step: a FoodItem, null (not found), or an
  /// object to throw.
  final List<Object?> script;
  int calls = 0;

  @override
  Future<FoodItem?> lookupBarcode(String barcode) async {
    final step = script[calls < script.length ? calls : script.length - 1];
    calls++;
    if (step is FoodItem?) return step;
    throw step;
  }
}

Finder _barcodeField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'e.g. 8901234567890',
);

Future<void> _openScanner(WidgetTester tester, _ScriptedLookup lookup) async {
  await _bigScreen(tester);
  final scanner = DefaultBarcodeScannerService()
    ..setCameraPermissionState(true);
  await tester.pumpWidget(
    MaterialApp(
      home: UnifiedFoodScannerScreen(
        initialMode: UnifiedScanMode.barcode,
        barcodeScannerService: scanner,
        barcodeFoodService: lookup,
        currentMealId: 'Lunch',
        currentMealTitle: 'Lunch',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _lookUp(WidgetTester tester, String code) async {
  await tester.enterText(_barcodeField(), code);
  await tester.tap(find.text('Lookup'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('result card', () {
    testWidgets('known nutrition looks and works as before', (tester) async {
      await _openCard(tester, _known);

      expect(find.text('190 kcal'), findsOneWidget);
      expect(find.text('4.0g'), findsOneWidget);
      expect(
        find.byKey(const Key('scanned_nutrition_unavailable')),
        findsNothing,
      );
      expect(find.text('LOG TO MEAL'), findsOneWidget);
      expect(find.textContaining('ADD TO'), findsOneWidget);
      expect(find.text('Save Product'), findsOneWidget);
      expect(find.byKey(const Key('scanned_enter_nutrition')), findsNothing);
      expect(
        find.byKey(const Key('scanned_partial_nutrition_note')),
        findsNothing,
      );
    });

    testWidgets('a known real zero still shows 0, not "unavailable"', (
      tester,
    ) async {
      await _openCard(
        tester,
        _known.copyWith(
          calories: 0,
          protein: 0,
          carbohydrates: 0,
          fats: 0,
          name: 'Sparkling water',
        ),
      );
      expect(find.text('0 kcal'), findsOneWidget);
      expect(
        find.byKey(const Key('scanned_nutrition_unavailable')),
        findsNothing,
      );
      expect(find.text('LOG TO MEAL'), findsOneWidget);
    });

    testWidgets(
      'no nutrition data: says so, shows no zeros, cannot be logged',
      (tester) async {
        await _openCard(tester, _unavailable);

        expect(find.text('Boomer Bubble Gum'), findsOneWidget);
        expect(find.text('Nutrition data unavailable'), findsOneWidget);
        expect(find.textContaining('kcal'), findsNothing);
        expect(find.text('0.0g'), findsNothing);
        expect(find.text('LOG TO MEAL'), findsNothing);
        expect(find.textContaining('ADD TO'), findsNothing);
        expect(find.text('Save Product'), findsNothing);
        expect(find.text('Breakfast'), findsNothing);
        expect(
          find.byKey(const Key('scanned_enter_nutrition')),
          findsOneWidget,
        );
      },
    );

    testWidgets('unknown calories cannot be logged either', (tester) async {
      await _openCard(tester, _noCalories);

      expect(
        find.byKey(const Key('scanned_nutrition_unavailable')),
        findsNothing,
      );
      expect(find.text('— kcal'), findsOneWidget);
      expect(find.text('10.0g'), findsOneWidget);
      expect(find.text('LOG TO MEAL'), findsNothing);
      expect(find.textContaining('ADD TO'), findsNothing);
      expect(find.byKey(const Key('scanned_enter_nutrition')), findsOneWidget);
    });

    testWidgets('partial data: missing values show a dash and a note', (
      tester,
    ) async {
      await _openCard(tester, _partial);

      expect(find.text('120 kcal'), findsOneWidget);
      expect(find.text('3.0g'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(
        find.byKey(const Key('scanned_partial_nutrition_note')),
        findsOneWidget,
      );
      // Calories are known, so logging is still offered.
      expect(find.text('LOG TO MEAL'), findsOneWidget);
    });

    testWidgets('manual entry opens the editor with empty, required fields', (
      tester,
    ) async {
      await _openCard(tester, _unavailable);

      await tester.tap(find.byKey(const Key('scanned_enter_nutrition')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomFoodModal), findsOneWidget);
      TextFormField field(String label) => tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, label),
      );
      expect(field('Calories (kcal) *').controller!.text, isEmpty);
      expect(field('Protein (g) *').controller!.text, isEmpty);
      expect(field('Carbs (g) *').controller!.text, isEmpty);
      expect(field('Fat (g) *').controller!.text, isEmpty);
      expect(field('Food Name *').controller!.text, 'Boomer Bubble Gum');
    });

    testWidgets('values typed in are saved as a custom food with the barcode', (
      tester,
    ) async {
      await _openCard(tester, _unavailable);
      await tester.tap(find.byKey(const Key('scanned_enter_nutrition')));
      await tester.pumpAndSettle();

      Future<void> type(String label, String text) =>
          tester.enterText(find.widgetWithText(TextFormField, label), text);
      await type('Calories (kcal) *', '15');
      await type('Protein (g) *', '0');
      await type('Carbs (g) *', '4');
      await type('Fat (g) *', '0');
      await tester.ensureVisible(find.text('UPDATE FOOD'));
      await tester.tap(find.text('UPDATE FOOD'));
      await tester.pumpAndSettle();

      final saved = LocalStorage.getCustomFoods()
          .map(FoodItem.fromJson)
          .where((f) => f.barcode == '8902433040207')
          .toList();
      expect(saved, hasLength(1));
      expect(saved.single.calories, 15);
      expect(saved.single.carbohydrates, 4);
      expect(saved.single.isCustom, isTrue);
      expect(saved.single.hasUnknownNutrition, isFalse);
    });
  });

  group('scanner recovery after lookup problems', () {
    testWidgets('a network error shows a message and a retry succeeds', (
      tester,
    ) async {
      final lookup = _ScriptedLookup([
        const OpenFoodFactsException(message: 'offline', isNetworkError: true),
        _known,
      ]);
      await _openScanner(tester, lookup);

      await _lookUp(tester, '1');

      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.byType(ScannedFoodResultCard), findsNothing);

      // Manual lookup works again straight away: nothing is stuck.
      await _lookUp(tester, '1');
      expect(lookup.calls, 2);
      expect(find.byType(ScannedFoodResultCard), findsOneWidget);
      expect(find.text('Granola Bar'), findsOneWidget);
    });

    testWidgets('the retry button in the message resumes scanning', (
      tester,
    ) async {
      final lookup = _ScriptedLookup([
        const OpenFoodFactsException(message: 'server', statusCode: 503),
        _known,
      ]);
      await _openScanner(tester, lookup);
      await _lookUp(tester, '1');
      expect(find.textContaining('could not be reached'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be reached'), findsNothing);
      await _lookUp(tester, '1');
      expect(find.text('Granola Bar'), findsOneWidget);
    });

    testWidgets('a timeout is reported and can be retried', (tester) async {
      final lookup = _ScriptedLookup([TimeoutException('slow'), _known]);
      await _openScanner(tester, lookup);

      await _lookUp(tester, '1');
      expect(find.textContaining('timed out'), findsOneWidget);

      await _lookUp(tester, '1');
      expect(find.text('Granola Bar'), findsOneWidget);
    });

    testWidgets('any other error gets a generic message and can be retried', (
      tester,
    ) async {
      final lookup = _ScriptedLookup([StateError('boom'), _known]);
      await _openScanner(tester, lookup);

      await _lookUp(tester, '1');
      expect(find.textContaining('lookup failed'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);

      await _lookUp(tester, '1');
      expect(find.text('Granola Bar'), findsOneWidget);
    });

    testWidgets('a product that does not exist is still reported', (
      tester,
    ) async {
      final lookup = _ScriptedLookup([null]);
      await _openScanner(tester, lookup);

      await _lookUp(tester, '999');

      expect(find.text('Product Not Found'), findsOneWidget);
    });

    testWidgets('a product without nutrition opens the unavailable card', (
      tester,
    ) async {
      final lookup = _ScriptedLookup([_unavailable]);
      await _openScanner(tester, lookup);

      await _lookUp(tester, '8902433040207');

      expect(find.text('Boomer Bubble Gum'), findsOneWidget);
      expect(find.text('Nutrition data unavailable'), findsOneWidget);
      expect(find.text('LOG TO MEAL'), findsNothing);
    });
  });
}
