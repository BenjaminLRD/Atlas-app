import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Phase 5 — Barcode Scanner & Result Card Widget Tests', () {
    testWidgets('1. Scanner button renders in Food Search Sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodSearchSheet(mealId: 'Breakfast', mealTitle: 'Breakfast'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADD FOOD'), findsOneWidget);
      expect(find.text('Scan Barcode'), findsOneWidget);
    });

    testWidgets(
      '3. Product result card renders with product image, name, brand, macros',
      (tester) async {
        const food = FoodItem(
          id: 'scanned_8906000000001',
          name: 'Whey Protein Isolate',
          brand: 'MuscleBlaze',
          calories: 120.0,
          protein: 25.0,
          carbohydrates: 2.0,
          fats: 1.0,
          servingSize: '30g',
          isPackaged: true,
          imageUrl: '', // missing image to test fallback
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ScannedFoodResultCard(
                food: food,
                currentMealId: 'Breakfast',
                currentMealTitle: 'Breakfast',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Whey Protein Isolate'), findsOneWidget);
        expect(find.text('MuscleBlaze'), findsOneWidget);
        expect(find.text('120 kcal'), findsOneWidget);
        expect(find.text('25.0g'), findsOneWidget);
        expect(find.text('Save Product'), findsOneWidget);
      },
    );

    testWidgets('4. Add food action works from ScannedFoodResultCard', (
      tester,
    ) async {
      const food = FoodItem(
        id: 'scanned_777',
        name: 'Greek Yogurt 0%',
        brand: 'Epigamia',
        calories: 90.0,
        protein: 10.0,
        carbohydrates: 6.0,
        fats: 0.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScannedFoodResultCard(
              food: food,
              currentMealId: 'Breakfast',
              currentMealTitle: 'Breakfast',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap ADD TO BREAKFAST button
      await tester.tap(find.text('ADD TO BREAKFAST'));
      await tester.pumpAndSettle();

      // Food added to fitness provider meal entries
      final todaysMeals = FitnessProvider.instance.todaysMeals;
      final breakfast = todaysMeals.firstWhere(
        (m) => m.name.toLowerCase() == 'breakfast',
      );
      expect(
        breakfast.consumedFoods.any((cf) => cf.food.name == 'Greek Yogurt 0%'),
        isTrue,
      );
    });

    testWidgets('5. Missing image fallback works safely', (tester) async {
      const foodWithoutImage = FoodItem(
        id: 'scanned_000',
        name: 'Whole Grain Bread',
        calories: 80.0,
        imageUrl: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScannedFoodResultCard(food: foodWithoutImage)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fastfood_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
