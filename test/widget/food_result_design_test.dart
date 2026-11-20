import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/food_result_parts.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

const FoodItem _verified = FoodItem(
  id: 'scanned_1',
  name: 'Granola Bar With A Rather Long Product Name For A Small Phone',
  brand: 'Acme Natural Foods International',
  calories: 190,
  protein: 4,
  carbohydrates: 29,
  fats: 7,
  isPackaged: true,
  barcode: '1',
);

const FoodItem _unavailable = FoodItem(
  id: 'scanned_2',
  name: 'Boomer Bubble Gum',
  calories: 0,
  protein: 0,
  carbohydrates: 0,
  fats: 0,
  isPackaged: true,
  barcode: '2',
  unknownNutrients: FoodItem.coreNutrients,
);

const FoodItem _partial = FoodItem(
  id: 'scanned_3',
  name: 'Mystery Snack',
  calories: 120,
  protein: 3,
  carbohydrates: 0,
  fats: 0,
  isPackaged: true,
  barcode: '3',
  unknownNutrients: {FoodItem.carbohydrateKey, FoodItem.fatKey},
);

/// A small Android phone (360 x 640 logical pixels).
Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openSheet(WidgetTester tester, FoodItem food) async {
  await _phone(tester);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('source badge', () {
    Future<void> show(WidgetTester tester, FoodSourceKind kind) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SourceBadge(kind: kind)),
          ),
        );

    testWidgets('each source says what it is, and an AI estimate never '
        'sounds verified', (tester) async {
      final expected = {
        FoodSourceKind.database: 'Product database',
        FoodSourceKind.userEntry: 'Entered by you',
        FoodSourceKind.aiEstimate: 'Unverified AI estimate',
        FoodSourceKind.aiLow: 'Low confidence • check it',
        FoodSourceKind.unavailable: 'Nutrition unavailable',
      };
      for (final entry in expected.entries) {
        await show(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      }
      await show(tester, FoodSourceKind.aiEstimate);
      expect(find.textContaining('Verified'), findsNothing);
      expect(find.textContaining('database'), findsNothing);
    });
  });

  group('macro strip', () {
    testWidgets('unknown values are dashes, not zeros, and draw no bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MacroStrip(
              entries: [
                MacroEntry(
                  'Protein',
                  3,
                  FoodResultStyle.protein,
                  energyPerGram: 4,
                ),
                MacroEntry(
                  'Carbs',
                  null,
                  FoodResultStyle.carbs,
                  energyPerGram: 4,
                ),
                MacroEntry('Fat', null, FoodResultStyle.fat, energyPerGram: 9),
              ],
            ),
          ),
        ),
      );
      expect(find.text('3.0g'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0.0g'), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('known values draw the calorie split bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MacroStrip(
              prefix: '~',
              entries: [
                MacroEntry(
                  'Protein',
                  10,
                  FoodResultStyle.protein,
                  energyPerGram: 4,
                ),
                MacroEntry(
                  'Carbs',
                  20,
                  FoodResultStyle.carbs,
                  energyPerGram: 4,
                ),
                MacroEntry('Fat', 5, FoodResultStyle.fat, energyPerGram: 9),
              ],
            ),
          ),
        ),
      );
      expect(find.text('~10.0g'), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('serving row', () {
    testWidgets('the edit control is a visible, tappable button', (
      tester,
    ) async {
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServingRow(value: '~450 ml', onEdit: () => edits++),
          ),
        ),
      );
      expect(find.text('Portion: ~450 ml'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      expect(edits, 1);
    });
  });

  group('scanned product sheet on a 360 x 640 phone', () {
    testWidgets('verified database nutrition fits without overflow', (
      tester,
    ) async {
      await _openSheet(tester, _verified);

      expect(tester.takeException(), isNull);
      expect(find.text('Product database'), findsOneWidget);
      expect(find.text('190 kcal'), findsOneWidget);
      expect(find.text('4.0g'), findsOneWidget);
      expect(find.textContaining('AI'), findsNothing);
      // The primary action and the edit path are both on screen.
      expect(find.textContaining('ADD TO'), findsOneWidget);
      expect(find.text('Edit Product Details'), findsOneWidget);
    });

    testWidgets('unavailable nutrition is labelled, with no numbers shown', (
      tester,
    ) async {
      await _openSheet(tester, _unavailable);

      expect(tester.takeException(), isNull);
      expect(find.text('Nutrition unavailable'), findsOneWidget);
      expect(
        find.byKey(const Key('scanned_nutrition_unavailable')),
        findsOneWidget,
      );
      expect(find.text('Product database'), findsNothing);
      expect(find.textContaining('kcal'), findsNothing);
      expect(find.byKey(const Key('scanned_enter_nutrition')), findsOneWidget);
      expect(find.textContaining('ADD TO'), findsNothing);
    });

    testWidgets('partial data shows dashes and a note', (tester) async {
      await _openSheet(tester, _partial);

      expect(tester.takeException(), isNull);
      expect(find.text('120 kcal'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(
        find.byKey(const Key('scanned_partial_nutrition_note')),
        findsOneWidget,
      );
    });

    testWidgets('a food the user entered is not called a database result', (
      tester,
    ) async {
      await _openSheet(tester, _verified.copyWith(isCustom: true));

      expect(find.text('Entered by you'), findsOneWidget);
      expect(find.text('Product database'), findsNothing);
    });
  });
}
