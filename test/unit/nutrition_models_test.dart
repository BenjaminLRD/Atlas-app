import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/macro_target.dart';
import 'package:aizawl_gym/models/daily_nutrition.dart';

void main() {
  group('Nutrition Models Tests', () {
    test('FoodItem serialization and copyWith', () {
      const food = FoodItem(
        id: 'f1',
        name: 'Oatmeal',
        calories: 350.0,
        proteinGrams: 12.0,
        carbsGrams: 60.0,
        fatGrams: 6.0,
        servingSize: '1 cup',
      );

      final json = food.toJson();
      final restored = FoodItem.fromJson(json);

      expect(restored.id, 'f1');
      expect(restored.name, 'Oatmeal');
      expect(restored.calories, 350.0);
      expect(restored.proteinGrams, 12.0);

      final updated = restored.copyWith(calories: 380.0);
      expect(updated.calories, 380.0);
      expect(updated.proteinGrams, 12.0);
    });

    test('MealEntry derived macro calculation and category parsing', () {
      final meal = MealEntry(
        id: 'm1',
        name: 'Post-Workout Lunch',
        category: MealCategory.lunch,
        timeLabel: '1:00 PM',
        items: [
          FoodItem(id: '1', name: 'Chicken', calories: 400, proteinGrams: 50, carbsGrams: 0, fatGrams: 8),
          FoodItem(id: '2', name: 'Rice', calories: 200, proteinGrams: 4, carbsGrams: 45, fatGrams: 1),
        ],
        isCompleted: true,
      );

      expect(meal.totalCalories, 600.0);
      expect(meal.totalProtein, 54.0);
      expect(meal.totalCarbs, 45.0);
      expect(meal.totalFat, 9.0);
      expect(meal.macrosSummary, contains('P: 54g'));

      final json = meal.toJson();
      final restored = MealEntry.fromJson(json);

      expect(restored.category, MealCategory.lunch);
      expect(restored.items.length, 2);
      expect(restored.isCompleted, isTrue);
    });

    test('MacroTarget default values and copyWith', () {
      final target = MacroTarget.defaultTarget();
      expect(target.calories, 2500.0);
      expect(target.proteinGrams, 160.0);

      final updated = target.copyWith(calories: 2800.0);
      expect(updated.calories, 2800.0);
      expect(updated.proteinGrams, 160.0);
    });

    test('DailyNutrition totals and calories remaining calculation', () {
      final daily = DailyNutrition.defaultForDate('2026-07-29');

      expect(daily.date, '2026-07-29');
      expect(daily.meals.length, 4);
      expect(daily.totalCaloriesConsumed, greaterThan(0));
      expect(daily.totalProteinConsumed, greaterThan(0));
      expect(daily.caloriesRemaining, lessThanOrEqualTo(daily.targets.calories));

      final json = daily.toJson();
      final restored = DailyNutrition.fromJson(json);

      expect(restored.date, '2026-07-29');
      expect(restored.meals.length, 4);
    });
  });
}
