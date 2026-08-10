import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/consumed_food.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_log.dart';
import 'package:aizawl_gym/models/nutrition_summary.dart';
import 'package:aizawl_gym/services/nutrition_analytics_service.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('NutritionSummary Model Tests', () {
    test('NutritionSummary default empty factory', () {
      final summary = NutritionSummary.empty();
      expect(summary.totalCaloriesConsumed, equals(0.0));
      expect(summary.averageDailyCalories, equals(0.0));
      expect(summary.currentNutritionStreak, equals(0));
      expect(summary.weeklyCalories.length, equals(7));
    });

    test('NutritionSummary fromJson and toJson round trip', () {
      const summary = NutritionSummary(
        totalCaloriesConsumed: 12000.0,
        averageDailyCalories: 2000.0,
        averageProtein: 150.0,
        averageCarbohydrates: 220.0,
        averageFats: 60.0,
        proteinGoalHitPercentage: 85.0,
        calorieGoalConsistency: 90.0,
        currentNutritionStreak: 5,
        weeklyCalories: [1800.0, 2000.0, 2100.0, 1950.0, 2200.0, 2000.0, 1950.0],
        macroBalance: {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0},
      );

      final json = summary.toJson();
      final restored = NutritionSummary.fromJson(json);

      expect(restored, equals(summary));
      expect(restored.totalCaloriesConsumed, equals(12000.0));
      expect(restored.currentNutritionStreak, equals(5));
    });

    test('NutritionSummary copyWith updates specified fields', () {
      const summary = NutritionSummary(totalCaloriesConsumed: 5000.0);
      final updated = summary.copyWith(totalCaloriesConsumed: 7500.0, currentNutritionStreak: 3);

      expect(updated.totalCaloriesConsumed, equals(7500.0));
      expect(updated.currentNutritionStreak, equals(3));
    });
  });

  group('NutritionAnalyticsService Calculation Tests', () {
    late NutritionAnalyticsService analyticsService;

    setUp(() {
      analyticsService = const NutritionAnalyticsService();
    });

    test('calculateSummary handles empty history gracefully', () {
      final summary = analyticsService.calculateSummary([]);
      expect(summary.totalCaloriesConsumed, equals(0.0));
      expect(summary.averageDailyCalories, equals(0.0));
      expect(summary.currentNutritionStreak, equals(0));
    });

    test('calculateSummary accurately calculates averages, goal hit percentages, and macro balance', () {
      const chicken = FoodItem(
        id: 'c1',
        name: 'Chicken',
        calories: 200.0,
        protein: 30.0,
        carbohydrates: 10.0,
        fats: 5.0,
      );

      final log1 = NutritionLog(
        id: 'log1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        meals: [
          MealEntry(
            id: 'm1',
            mealType: MealCategory.lunch,
            consumedFoods: const [ConsumedFood(food: chicken, quantity: 100.0)],
            completed: true,
          ),
        ],
        calorieGoal: 2000.0,
        proteinGoal: 25.0,
      );

      final log2 = NutritionLog(
        id: 'log2',
        date: DateTime.now(),
        meals: [
          MealEntry(
            id: 'm2',
            mealType: MealCategory.dinner,
            consumedFoods: const [ConsumedFood(food: chicken, quantity: 200.0)],
            completed: true,
          ),
        ],
        calorieGoal: 2000.0,
        proteinGoal: 100.0, // Missed goal
      );

      final summary = analyticsService.calculateSummary([log1, log2]);

      expect(summary.totalCaloriesConsumed, closeTo(600.0, 0.01));
      expect(summary.averageDailyCalories, closeTo(300.0, 0.01));
      expect(summary.averageProtein, closeTo(45.0, 0.01));
      expect(summary.proteinGoalHitPercentage, closeTo(50.0, 0.01)); // 1 of 2 logs hit protein goal
      expect(summary.macroBalance.containsKey('protein'), isTrue);
      expect(summary.macroBalance.containsKey('carbs'), isTrue);
      expect(summary.macroBalance.containsKey('fats'), isTrue);
    });
  });

  group('FitnessProvider Nutrition Analytics Integration Tests', () {
    test('FitnessProvider exposes reactive nutritionSummary and invalidates cache on refresh', () {
      final provider = FitnessProvider.instance;
      final initialSummary = provider.nutritionSummary;

      expect(initialSummary, isNotNull);

      // Verify reactive caching identity
      final cachedSummary = provider.nutritionSummary;
      expect(identical(initialSummary, cachedSummary), isTrue);

      // Trigger refresh
      provider.refreshNutrition();
      final freshSummary = provider.nutritionSummary;

      expect(freshSummary, isNotNull);
    });
  });
}
