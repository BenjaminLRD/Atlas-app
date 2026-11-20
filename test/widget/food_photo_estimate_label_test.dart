import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/ai/vision/ai_vision_service.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

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

/// The model's answer for a can of Mountain Dew, with overrides.
String _answer({Map<String, dynamic> override = const {}}) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {
            'text': jsonEncode({
              'is_food': true,
              'foodName': 'Mountain Dew',
              'ingredients': ['carbonated water', 'corn syrup'],
              'servingSize': 450,
              'servingUnit': 'ml',
              'calories': 207,
              'protein': 0,
              'carbohydrates': 56,
              'fats': 0,
              'confidence': 0.95,
              ...override,
            }),
          },
        ],
      },
    },
  ],
});

Future<void> _scan(
  WidgetTester tester, {
  Map<String, dynamic> override = const {},
  Size size = const Size(900, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  FoodAIVisionService.setInstance(
    FoodAIVisionService(
      config: AIConfig(
        proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
        accessTokenProvider: () => 'user-token',
      ),
      httpClient: MockClient(
        (_) async => http.Response(_answer(override: override), 200),
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

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FoodAIVisionService.resetInstance);

  testWidgets('a 95%-sure answer is still only an unverified estimate', (
    tester,
  ) async {
    await _scan(tester);

    expect(find.text('Mountain Dew'), findsOneWidget);
    expect(find.text('Portion: ~450 ml'), findsOneWidget);
    expect(find.text('~207 kcal'), findsOneWidget);
    expect(find.text('~56.0g'), findsOneWidget);

    expect(_text(tester, 'ai_estimate_label'), 'Unverified AI estimate');
    expect(find.textContaining('Confidence'), findsNothing);
    expect(find.textContaining('High'), findsNothing);
    expect(find.text('AI FOOD ESTIMATE'), findsOneWidget);
  });

  testWidgets('it says the numbers are not package or database data', (
    tester,
  ) async {
    await _scan(tester);

    final disclaimer = _text(tester, 'ai_estimate_disclaimer');
    expect(disclaimer, contains('Estimated by AI from your photo'));
    expect(disclaimer, contains('not package or database data'));
    expect(disclaimer, contains('Check the portion and values'));
  });

  testWidgets('a low model confidence is flagged', (tester) async {
    await _scan(tester, override: {'confidence': 0.3});

    expect(_text(tester, 'ai_estimate_label'), 'Low confidence • check it');
    expect(find.textContaining('High'), findsNothing);
  });

  testWidgets('the result fits a 360 x 640 phone, long name and all', (
    tester,
  ) async {
    await _scan(
      tester,
      size: const Size(360, 640),
      override: {
        'foodName': 'Mountain Dew Citrus Soda With Real Sugar In A Tall Can',
        'calories': 500,
        'protein': 5,
        'carbohydrates': 10,
        'fats': 3,
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Add To'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byKey(const Key('ai_estimate_mismatch')), findsOneWidget);
  });

  testWidgets('numbers that add up show no warning', (tester) async {
    await _scan(tester);
    expect(find.byKey(const Key('ai_estimate_mismatch')), findsNothing);
  });

  testWidgets('numbers that do not add up are flagged', (tester) async {
    // All four numbers given, so they can be compared.
    await _scan(
      tester,
      override: {'calories': 500, 'protein': 5, 'carbohydrates': 10, 'fats': 3},
    );

    expect(find.byKey(const Key('ai_estimate_mismatch')), findsOneWidget);
    expect(find.textContaining('do not add up'), findsOneWidget);
  });

  testWidgets(
    'a beverage in millilitres keeps ml everywhere, even in different '
    'spellings',
    (tester) async {
      await _scan(tester, override: {'servingUnit': 'Milliliters'});

      expect(find.text('Portion: ~450 ml'), findsOneWidget);
      expect(find.text('~207 kcal'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // The portion field is in ml, not g, and shows the portion totals.
      expect(find.text('Portion Size (ml)'), findsOneWidget);
      expect(find.text('Portion Size (g)'), findsNothing);
      final calories = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Calories (kcal)'),
      );
      expect(calories.controller!.text, '207');
    },
  );

  testWidgets('the portion and values stay editable before logging', (
    tester,
  ) async {
    await _scan(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // A smaller drink: the totals follow the portion (a third of 450 ml).
    await tester.enterText(
      find.widgetWithText(TextField, 'Portion Size (ml)'),
      '150',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Calories (kcal)'))
          .controller!
          .text,
      '69',
    );

    // And any value can be corrected by hand.
    await tester.enterText(
      find.widgetWithText(TextField, 'Calories (kcal)'),
      '60',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Portion: ~150 ml'), findsOneWidget);
    expect(find.text('~60 kcal'), findsOneWidget);

    await tester.tap(find.textContaining('Add To'));
    await tester.pumpAndSettle();
    expect(
      FitnessProvider.instance.todayNutritionLog.dailyCalories,
      closeTo(60, 1),
    );
  });
}
