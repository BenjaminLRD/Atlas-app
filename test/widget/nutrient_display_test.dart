import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/mock_food_database.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrient_status.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/custom_food_modal.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';
import 'package:atlas/widgets/nutrition/meal_card.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('the food search list', () {
    Future<void> search(WidgetTester tester, FoodItem food) async {
      bigScreen(tester);
      await FitnessProvider.instance.addCustomFood(food);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodSearchSheet(mealId: 'Lunch', mealTitle: 'Lunch'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Zorb');
      await tester.pumpAndSettle();
    }

    testWidgets('an unknown macro is a dash, not 0g', (tester) async {
      await search(
        tester,
        const FoodItem(
          id: 'custom_zorb',
          name: 'Zorb Bar',
          calories: 190,
          carbohydrates: 29,
          fats: 7,
          isCustom: true,
          unknownNutrients: {FoodItem.proteinKey},
        ),
      );

      expect(find.textContaining('— Protein'), findsOneWidget);
      expect(find.textContaining('0g Protein'), findsNothing);
      expect(find.textContaining('29g Carbs'), findsOneWidget);
    });

    testWidgets('unknown calories are a dash, not 0 kcal', (tester) async {
      await search(
        tester,
        const FoodItem(
          id: 'custom_zorb',
          name: 'Zorb Bar',
          calories: 0,
          protein: 4,
          isCustom: true,
          unknownNutrients: {FoodItem.calorieKey},
        ),
      );

      expect(find.textContaining('— kcal'), findsOneWidget);
      expect(find.textContaining('0 kcal'), findsNothing);
    });

    testWidgets('a real zero is shown as 0g', (tester) async {
      await search(
        tester,
        const FoodItem(
          id: 'custom_zorb',
          name: 'Zorb Bar',
          calories: 40,
          protein: 0,
          carbohydrates: 10,
          fats: 0,
          isCustom: true,
        ),
      );

      expect(find.textContaining('0g Protein'), findsOneWidget);
      expect(find.textContaining('0g Fat'), findsOneWidget);
    });
  });

  group('the meal card notes where logged numbers come from', () {
    Future<void> card(WidgetTester tester, FoodItem food) async {
      bigScreen(tester);
      final meal = MealEntry(
        id: 'm',
        mealType: MealCategory.lunch,
        consumedFoods: [ConsumedFood(food: food, quantity: 100, unit: 'g')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MealCard(meal: meal)),
        ),
      );
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
    }

    FoodItem withSource(NutritionSource? source) => FoodItem(
      id: 'x',
      name: 'Thing',
      calories: 100,
      protein: 5,
      nutritionSource: source ?? NutritionSource.unknown,
    );

    testWidgets('an entry from before sources were recorded says so', (
      tester,
    ) async {
      await card(tester, withSource(null));
      expect(find.textContaining('source not recorded'), findsOneWidget);
    });

    testWidgets('an AI estimate is marked as an estimate', (tester) async {
      await card(tester, withSource(NutritionSource.aiEstimate));
      expect(find.textContaining('• estimate'), findsOneWidget);
      expect(find.textContaining('source not recorded'), findsNothing);
    });

    testWidgets(
      'a product record, the built-in list and your own entry need no note',
      (tester) async {
        for (final source in [
          NutritionSource.openFoodFacts,
          NutritionSource.builtIn,
          NutritionSource.userEntry,
        ]) {
          await card(tester, withSource(source));
          expect(find.textContaining('source not recorded'), findsNothing);
          expect(find.textContaining('• estimate'), findsNothing);
        }
      },
    );

    testWidgets('old numbers are shown, not hidden or relabelled verified', (
      tester,
    ) async {
      await card(tester, withSource(null));
      expect(find.textContaining('100 kcal'), findsWidgets);
      expect(find.textContaining('erified'), findsNothing);
    });
  });

  group('the built-in food list', () {
    test('is marked as typical values, not as a product record', () {
      final foods = MockFoodDatabase.defaultFoods;
      expect(foods.length, greaterThan(200));
      expect(
        foods.every((f) => f.nutritionSource == NutritionSource.builtIn),
        isTrue,
      );
    });

    test('the tag changes nothing else about a food', () {
      final chicken = MockFoodDatabase.getFoodById('protein_001')!;
      expect(chicken.name, 'Chicken Breast');
      expect(chicken.nutritionBasis, NutritionBasis.per100g);
      expect(chicken.unknownNutrients, isEmpty);
    });

    test('the tag survives saving and loading', () {
      final chicken = MockFoodDatabase.getFoodById('protein_001')!;
      final back = FoodItem.fromJson(chicken.toJson());
      expect(back.nutritionSource, NutritionSource.builtIn);
    });
  });

  group('the barcode sheet shows the other nutrients honestly', () {
    Future<void> sheet(WidgetTester tester, FoodItem food) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScannedFoodResultCard(food: food)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('given values are shown and missing ones are dashes', (
      tester,
    ) async {
      await sheet(
        tester,
        const FoodItem(
          id: 'scanned_1',
          name: 'Cola',
          servingUnit: 'ml',
          calories: 49,
          protein: 0,
          carbohydrates: 12.3,
          fats: 0,
          sugar: 12.3,
          saturatedFat: 0,
          isPackaged: true,
          barcode: '1',
          nutritionBasis: NutritionBasis.per100ml,
          nutritionSource: NutritionSource.openFoodFacts,
        ),
      );

      expect(find.text('Sugar 12.3g'), findsOneWidget);
      expect(find.text('Sat. fat 0.0g'), findsOneWidget);
      expect(find.text('Fibre —'), findsOneWidget);
      expect(find.text('Salt —'), findsOneWidget);
      expect(find.text('Sodium —'), findsOneWidget);
    });

    testWidgets('the missing-values note no longer says they count as 0', (
      tester,
    ) async {
      await sheet(
        tester,
        const FoodItem(
          id: 'scanned_2',
          name: 'Mystery',
          calories: 120,
          protein: 3,
          isPackaged: true,
          barcode: '2',
          unknownNutrients: {FoodItem.carbohydrateKey, FoodItem.fatKey},
        ),
      );

      final note = tester
          .widget<Text>(find.byKey(const Key('scanned_partial_nutrition_note')))
          .data!;
      expect(note, isNot(contains('count as 0')));
      expect(note, contains('unknown'));
    });
  });

  group('manual entry', () {
    testWidgets(
      'saving records the values as yours and keeps unknowns unknown',
      (tester) async {
        bigScreen(tester);
        const mine = FoodItem(
          id: 'custom_mine',
          name: 'My Granola',
          calories: 400,
          protein: 10,
          carbohydrates: 60,
          fats: 12,
          isCustom: true,
        );
        await FitnessProvider.instance.addCustomFood(mine);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CustomFoodModal.show(ctx, initialFood: mine),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The two new optional fields start empty: not known, not 0.
        expect(find.text('Saturated fat (g)'), findsOneWidget);
        expect(find.text('Salt (g)'), findsOneWidget);

        await tester.ensureVisible(find.text('UPDATE FOOD'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('UPDATE FOOD'));
        await tester.pumpAndSettle();

        final saved = FitnessProvider.instance.availableFoods.firstWhere(
          (f) => f.id == 'custom_mine',
        );
        expect(saved.nutritionSource, NutritionSource.userEntry);
        expect(saved.saturatedFat, isNull);
        expect(saved.salt, isNull);
      },
    );

    testWidgets('text that is not a number is rejected, never saved as 0', (
      tester,
    ) async {
      bigScreen(tester);
      const mine = FoodItem(
        id: 'custom_text',
        name: 'My Soup',
        calories: 120,
        protein: 4,
        carbohydrates: 10,
        fats: 3,
        isCustom: true,
      );
      await FitnessProvider.instance.addCustomFood(mine);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CustomFoodModal.show(ctx, initialFood: mine),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Protein (g) *'),
        'abc',
      );
      await tester.ensureVisible(find.text('UPDATE FOOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPDATE FOOD'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number'), findsOneWidget);
      final stored = FitnessProvider.instance.availableFoods.firstWhere(
        (f) => f.id == 'custom_text',
      );
      expect(stored.protein, 4); // unchanged: nothing was saved as 0

      // A typed 0 is a value the user chose, and is accepted.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Protein (g) *'),
        '0',
      );
      await tester.tap(find.text('UPDATE FOOD'));
      await tester.pumpAndSettle();
      final saved = FitnessProvider.instance.availableFoods.firstWhere(
        (f) => f.id == 'custom_text',
      );
      expect(saved.protein, 0);
      expect(saved.statusOf(FoodItem.proteinKey), NutrientStatus.knownZero);
    });
  });
}
