import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

void main() {
  group('NutritionCalculator Unit Tests', () {
    const chicken = FoodItem(
      id: 'chicken_breast_001',
      name: 'Chicken Breast',
      category: 'Protein',
      servingSize: '100g',
      servingUnit: 'grams',
      calories: 165.0,
      protein: 31.0,
      carbohydrates: 0.0,
      fats: 3.6,
      fiber: 0.0,
    );

    test('100g serving calculates base nutrition values', () {
      final scaled = NutritionCalculator.calculate(chicken, 100.0, 'grams');
      expect(scaled.calories, equals(165.0));
      expect(scaled.protein, equals(31.0));
      expect(scaled.carbohydrates, equals(0.0));
      expect(scaled.fats, equals(3.6));
    });

    test('250g serving scales nutrition proportionally (2.5x)', () {
      final scaled = NutritionCalculator.calculate(chicken, 250.0, 'grams');
      expect(scaled.calories, equals(412.5));
      expect(scaled.protein, equals(77.5));
      expect(scaled.carbohydrates, equals(0.0));
      expect(scaled.fats, equals(9.0));
    });

    test('50g serving scales nutrition proportionally (0.5x)', () {
      final scaled = NutritionCalculator.calculate(chicken, 50.0, 'grams');
      expect(scaled.calories, equals(82.5));
      expect(scaled.protein, equals(15.5));
      expect(scaled.carbohydrates, equals(0.0));
      expect(scaled.fats, equals(1.8));
    });

    test('Unit scaling handles piece, serving, cup correctly', () {
      const apple = FoodItem(
        id: 'apple_001',
        name: 'Apple',
        servingSize: '1 medium',
        servingUnit: 'piece',
        calories: 95.0,
        protein: 0.5,
        carbohydrates: 25.0,
        fats: 0.3,
        fiber: 4.4,
      );

      final scaled2Pieces = NutritionCalculator.calculate(apple, 2.0, 'piece');
      expect(scaled2Pieces.calories, equals(190.0));
      expect(scaled2Pieces.protein, equals(1.0));
      expect(scaled2Pieces.carbohydrates, equals(50.0));
      expect(scaled2Pieces.fiber, equals(8.8));
    });
  });
}
