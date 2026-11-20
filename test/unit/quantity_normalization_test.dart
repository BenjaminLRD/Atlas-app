import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';
import 'package:atlas/widgets/nutrition/meal_card.dart';

const _solid = FoodItem(
  id: 'solid',
  name: 'Oats',
  servingUnit: 'grams',
  calories: 200,
  protein: 10,
  carbohydrates: 30,
  fats: 4,
  nutritionBasis: NutritionBasis.per100g,
);

const _drink = FoodItem(
  id: 'drink',
  name: 'Cola',
  servingUnit: 'ml',
  calories: 40,
  protein: 0,
  carbohydrates: 10,
  fats: 0,
  nutritionBasis: NutritionBasis.per100ml,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kg and L are converted to g and ml once', () {
    test('the calculator: 1 kg, 500 g, 1 L, 250 ml', () {
      expect(NutritionCalculator.calculate(_solid, 1, 'kg').calories, 2000);
      expect(NutritionCalculator.calculate(_solid, 500, 'g').calories, 1000);
      expect(NutritionCalculator.calculate(_drink, 1, 'L').calories, 400);
      expect(NutritionCalculator.calculate(_drink, 250, 'ml').calories, 100);
    });

    test('a logged entry gives the same numbers as the calculator', () {
      const cases = [
        (_solid, 1.0, 'kg', 2000.0),
        (_solid, 500.0, 'g', 1000.0),
        (_solid, 500.0, 'grams', 1000.0),
        (_drink, 1.0, 'L', 400.0),
        (_drink, 1.0, 'l', 400.0),
        (_drink, 250.0, 'ml', 100.0),
      ];
      for (final (food, qty, unit, kcal) in cases) {
        final entry = ConsumedFood(food: food, quantity: qty, unit: unit);
        expect(entry.calories, kcal, reason: '$qty $unit');
        expect(
          entry.calories,
          NutritionCalculator.calculate(food, qty, unit).calories,
          reason: '$qty $unit',
        );
      }
      expect(ConsumedFood(food: _solid, quantity: 1, unit: 'kg').protein, 100);
    });

    test('units that are not weight or volume still count per unit', () {
      expect(
        ConsumedFood(food: _solid, quantity: 2, unit: 'piece').calories,
        400,
      );
      expect(NutritionCalculator.calculate(_solid, 2, 'piece').calories, 400);
    });

    test('the quantity is stored as entered, not pre-converted', () {
      final json = ConsumedFood(food: _solid, quantity: 1, unit: 'kg').toJson();
      expect(json['quantity'], 1);
      expect(json['unit'], 'kg');
    });
  });

  group('saved entries from before keep their old totals', () {
    Map<String, dynamic> saved(String unit, double qty) => {
      'food': _solid.toJson(),
      'quantity': qty,
      'unit': unit,
    };

    test('an entry saved without a scaling version is read as it was', () {
      // Older versions counted 1 kg as one 100 g portion. History is not
      // rewritten.
      expect(ConsumedFood.fromJson(saved('kg', 1)).calories, 200);
      expect(ConsumedFood.fromJson(saved('L', 2)).calories, 400);
    });

    test('grams, ml and per-piece entries are the same in either version', () {
      expect(ConsumedFood.fromJson(saved('g', 500)).calories, 1000);
      expect(ConsumedFood.fromJson(saved('ml', 250)).calories, 500);
      expect(ConsumedFood.fromJson(saved('piece', 2)).calories, 400);
    });

    test('new entries are saved with the new version and read back', () {
      final json = ConsumedFood(food: _solid, quantity: 1, unit: 'kg').toJson();
      expect(json['scalingVersion'], 2);
      expect(ConsumedFood.fromJson(json).calories, 2000);
    });

    test('editing the quantity or unit moves an old entry to the new rule', () {
      final old = ConsumedFood.fromJson(saved('kg', 1));
      expect(old.copyWith(quantity: 2).calories, 4000);
      expect(old.copyWith(unit: 'g').calories, 200 * 0.01);
    });

    test('changing only the food keeps the old totals', () {
      final old = ConsumedFood.fromJson(saved('kg', 1));
      expect(old.copyWith(food: _solid).calories, 200);
    });
  });

  group('logging and totals', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      FitnessProvider.resetInstance();
    });

    double calories() =>
        FitnessProvider.instance.todayNutritionLog.dailyCalories;

    test('1 kg and 1 L add the converted amount to the day', () async {
      final before = calories();
      await FitnessProvider.instance.addFoodToMeal(
        'Breakfast',
        _solid,
        1,
        'kg',
      );
      expect(calories() - before, closeTo(2000, 0.01));

      final mid = calories();
      await FitnessProvider.instance.addFoodToMeal('Lunch', _drink, 1, 'L');
      expect(calories() - mid, closeTo(400, 0.01));
    });

    test('500 g and 250 ml are unchanged', () async {
      final before = calories();
      await FitnessProvider.instance.addFoodToMeal(
        'Breakfast',
        _solid,
        500,
        'g',
      );
      await FitnessProvider.instance.addFoodToMeal('Lunch', _drink, 250, 'ml');
      expect(calories() - before, closeTo(1100, 0.01));
    });
  });

  testWidgets('the meal card shows the same numbers as the totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();

    final meal = MealEntry(
      id: 'm1',
      mealType: MealCategory.breakfast,
      consumedFoods: [
        ConsumedFood(food: _solid, quantity: 1, unit: 'kg'),
        ConsumedFood(food: _drink, quantity: 250, unit: 'ml'),
        ConsumedFood(food: _solid, quantity: 2, unit: 'piece'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MealCard(meal: meal)),
      ),
    );
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 kg • 100g protein • 2000 kcal'),
      findsOneWidget,
    );
    expect(
      find.textContaining('250 ml • 0g protein • 100 kcal'),
      findsOneWidget,
    );
    // Per-piece rows used to be shown as quantity / 100.
    expect(
      find.textContaining('2 piece • 20g protein • 400 kcal'),
      findsOneWidget,
    );
    expect(find.textContaining('2500 kcal'), findsOneWidget);
  });
}
