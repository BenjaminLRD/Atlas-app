import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

FoodItem _food(NutritionBasis basis, {String unit = 'grams'}) => FoodItem(
  id: 'f_${basis.name}',
  name: 'Thing',
  servingUnit: unit,
  calories: 200,
  protein: 10,
  carbohydrates: 20,
  fats: 5,
  nutritionBasis: basis,
);

void main() {
  group('per 100 g: only a mass quantity scales it', () {
    final food = _food(NutritionBasis.per100g);

    test('grams and kilograms scale', () {
      expect(NutritionCalculator.tryCalculate(food, 250, 'g')!.calories, 500);
      expect(
        NutritionCalculator.tryCalculate(food, 250, 'grams')!.calories,
        500,
      );
      expect(NutritionCalculator.tryCalculate(food, 0.25, 'kg')!.calories, 500);
    });

    test('millilitres and litres are refused, not treated as grams', () {
      for (final unit in ['ml', 'mL', 'l', 'L']) {
        expect(NutritionCalculator.isUnitCompatible(food, unit), isFalse);
        expect(NutritionCalculator.tryCalculate(food, 250, unit), isNull);
      }
    });

    test('per-piece units keep their existing meaning', () {
      for (final unit in ['piece', 'cup', 'serving', 'bottle', 'pieces']) {
        final scaled = NutritionCalculator.tryCalculate(food, 2, unit)!;
        expect(
          scaled.calories,
          NutritionCalculator.calculate(food, 2, unit).calories,
        );
      }
    });
  });

  group('per 100 ml: only a volume quantity scales it', () {
    final food = _food(NutritionBasis.per100ml, unit: 'ml');

    test('millilitres and litres scale', () {
      expect(NutritionCalculator.tryCalculate(food, 330, 'ml')!.calories, 660);
      expect(NutritionCalculator.tryCalculate(food, 330, 'mL')!.protein, 33);
      expect(NutritionCalculator.tryCalculate(food, 0.33, 'L')!.calories, 660);
    });

    test('per-piece units keep their existing meaning', () {
      expect(NutritionCalculator.tryCalculate(food, 2, 'bottle'), isNotNull);
    });

    test('grams and kilograms are refused, not treated as millilitres', () {
      for (final unit in ['g', 'grams', 'G', 'kg']) {
        expect(NutritionCalculator.isUnitCompatible(food, unit), isFalse);
        expect(NutritionCalculator.tryCalculate(food, 330, unit), isNull);
      }
    });
  });

  group('unknown basis: no conversion is invented, old behaviour stays', () {
    final food = _food(NutritionBasis.unknown);

    test('every unit is accepted', () {
      for (final unit in ['g', 'grams', 'ml', 'kg', 'L', 'piece', 'cup']) {
        expect(NutritionCalculator.isUnitCompatible(food, unit), isTrue);
      }
    });

    test('and scales exactly as before', () {
      for (final unit in ['g', 'grams', 'ml', 'kg', 'L', 'piece', 'cup']) {
        final before = NutritionCalculator.calculate(food, 150, unit);
        final after = NutritionCalculator.tryCalculate(food, 150, unit)!;
        expect(after.calories, before.calories, reason: unit);
        expect(after.protein, before.protein, reason: unit);
      }
      expect(NutritionCalculator.calculate(food, 150, 'g').calories, 300);
      expect(NutritionCalculator.calculate(food, 2, 'piece').calories, 400);
    });
  });

  group('legacy and custom foods', () {
    test('a legacy built-in food in grams is per 100 g and still scales', () {
      final food = FoodItem.fromJson({
        'id': 'a',
        'name': 'Rice',
        'servingUnit': 'grams',
        'calories': 130,
        'isPackaged': false,
      });
      expect(food.nutritionBasis, NutritionBasis.per100g);
      expect(NutritionCalculator.tryCalculate(food, 200, 'g')!.calories, 260);
      expect(NutritionCalculator.tryCalculate(food, 200, 'ml'), isNull);
    });

    test('a custom food keeps working in any unit', () {
      final food = FoodItem.fromJson({
        'id': 'c',
        'name': 'My bar',
        'servingUnit': 'piece',
        'calories': 190,
        'isCustom': true,
      });
      expect(food.nutritionBasis, NutritionBasis.unknown);
      expect(NutritionCalculator.tryCalculate(food, 2, 'piece')!.calories, 380);
      expect(NutritionCalculator.tryCalculate(food, 50, 'g')!.calories, 95);
    });

    test('a legacy scanned product keeps working in any unit', () {
      final food = FoodItem.fromJson({
        'id': 'scanned_1',
        'name': 'Cola',
        'servingUnit': 'grams',
        'calories': 42,
        'isPackaged': true,
        'barcode': '1',
      });
      expect(food.nutritionBasis, NutritionBasis.unknown);
      expect(
        NutritionCalculator.tryCalculate(food, 330, 'ml')!.calories,
        138.6,
      );
    });
  });

  group('unknown basis is separate from unknown nutrients', () {
    test('a known basis can have unknown nutrients', () {
      final food = _food(
        NutritionBasis.per100ml,
        unit: 'ml',
      ).copyWith(unknownNutrients: {FoodItem.proteinKey});
      expect(food.nutritionBasis, NutritionBasis.per100ml);
      expect(food.isNutrientKnown(FoodItem.proteinKey), isFalse);
      expect(NutritionCalculator.tryCalculate(food, 100, 'ml'), isNotNull);
    });

    test('an unknown basis can have fully known nutrients', () {
      final food = _food(NutritionBasis.unknown);
      expect(food.hasUnknownNutrition, isFalse);
    });
  });

  group('logging', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      FitnessProvider.resetInstance();
    });

    double calories() =>
        FitnessProvider.instance.todayNutritionLog.dailyCalories;

    test('a matching unit is logged with the scaled amount', () async {
      final drink = _food(NutritionBasis.per100ml, unit: 'ml');
      final before = calories();
      await FitnessProvider.instance.addFoodToMeal(
        'Breakfast',
        drink,
        330,
        'ml',
      );
      expect(calories() - before, closeTo(660, 0.01));
    });

    test('a mismatched unit is refused and nothing is logged', () async {
      final drink = _food(NutritionBasis.per100ml, unit: 'ml');
      final before = calories();
      await expectLater(
        FitnessProvider.instance.addFoodToMeal('Breakfast', drink, 330, 'g'),
        throwsArgumentError,
      );
      expect(calories(), before);
    });

    test('unknown basis still logs in any unit', () async {
      final custom = _food(NutritionBasis.unknown, unit: 'piece');
      final before = calories();
      await FitnessProvider.instance.addFoodToMeal('Lunch', custom, 2, 'piece');
      expect(calories() - before, closeTo(400, 0.01));
    });
  });
}
