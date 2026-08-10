import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/consumed_food.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_log.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/data/nutrition_repository.dart';
import 'package:aizawl_gym/data/nutrition_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NutritionLog Model Tests', () {
    test('NutritionLog computes daily macro totals dynamically from meals', () {
      const chicken = FoodItem(
        id: 'c1',
        name: 'Chicken Breast',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
      );

      const oats = FoodItem(
        id: 'o1',
        name: 'Rolled Oats',
        calories: 389.0,
        protein: 16.9,
        carbohydrates: 66.3,
        fats: 6.9,
      );

      final meal1 = MealEntry(
        id: 'm1',
        mealType: MealCategory.breakfast,
        consumedFoods: const [
          ConsumedFood(food: oats, quantity: 100.0, unit: 'grams'),
        ],
        completed: true,
      );

      final meal2 = MealEntry(
        id: 'm2',
        mealType: MealCategory.lunch,
        consumedFoods: const [
          ConsumedFood(food: chicken, quantity: 200.0, unit: 'grams'),
        ],
        completed: true,
      );

      final log = NutritionLog(
        id: 'log_1',
        date: DateTime(2026, 8, 6),
        meals: [meal1, meal2],
        calorieGoal: 2000.0,
        proteinGoal: 150.0,
      );

      expect(log.dailyCalories, closeTo(389.0 + 330.0, 0.01));
      expect(log.dailyProtein, closeTo(16.9 + 62.0, 0.01));
      expect(log.dailyCarbohydrates, closeTo(66.3, 0.01));
      expect(log.dailyFats, closeTo(6.9 + 7.2, 0.01));
      expect(log.completedMeals, equals(2));

      expect(log.calorieProgress, closeTo(719.0 / 2000.0, 0.01));
      expect(log.proteinProgress, closeTo(78.9 / 150.0, 0.01));
    });

    test('NutritionLog fromJson and toJson round trip', () {
      final log = NutritionLog(
        id: 'log_test',
        date: DateTime(2026, 8, 6),
        meals: [
          MealEntry(
            id: 'b1',
            mealType: MealCategory.breakfast,
            consumedFoods: const [
              ConsumedFood(
                food: FoodItem(
                  id: 'egg',
                  name: 'Eggs',
                  calories: 155.0,
                  protein: 13.0,
                  carbohydrates: 1.1,
                  fats: 11.0,
                ),
                quantity: 100.0,
              ),
            ],
            completed: true,
          ),
        ],
        calorieGoal: 2400.0,
        proteinGoal: 180.0,
      );

      final json = log.toJson();
      final restored = NutritionLog.fromJson(json);

      expect(restored.id, equals('log_test'));
      expect(restored.calorieGoal, equals(2400.0));
      expect(restored.proteinGoal, equals(180.0));
      expect(restored.dailyCalories, equals(155.0));
      expect(restored.completedMeals, equals(1));
    });
  });

  group('NutritionRepository Persistence Tests', () {
    test('LocalNutritionRepository saves and retrieves NutritionLog history', () async {
      final repo = LocalNutritionRepository();

      final log = NutritionLog(
        id: 'log_persist_1',
        date: DateTime(2026, 8, 6),
        calorieGoal: 2500.0,
        proteinGoal: 170.0,
      );

      await repo.saveNutritionLog(log);
      final history = repo.getNutritionLogHistory();

      expect(history, isNotEmpty);
      expect(history.first.id, equals('log_persist_1'));
      expect(history.first.calorieGoal, equals(2500.0));
    });
  });

  group('NutritionService Operations & Data Flow Tests', () {
    late NutritionService service;

    setUp(() {
      service = NutritionService(LocalNutritionRepository());
    });

    test('addFoodToMeal appends ConsumedFood and updates today nutrition', () async {
      const chicken = FoodItem(
        id: 'chk_1',
        name: 'Chicken Breast',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
      );

      await service.addFoodToMeal('meal_lunch', chicken, 250.0, 'grams');
      final todayLog = service.getTodayNutrition();

      final lunchMeal = todayLog.meals.firstWhere(
        (m) => m.id == 'meal_lunch' || m.name.toLowerCase() == 'lunch',
      );

      expect(lunchMeal.consumedFoods, isNotEmpty);
      expect(lunchMeal.consumedFoods.first.quantity, equals(250.0));
      expect(todayLog.dailyProtein, closeTo(77.5, 0.01));
    });

    test('updateFoodQuantity updates portion size and recalculates macros', () async {
      const rice = FoodItem(
        id: 'rc_1',
        name: 'Rice',
        calories: 130.0,
        protein: 2.7,
        carbohydrates: 28.0,
        fats: 0.3,
      );

      await service.addFoodToMeal('meal_dinner', rice, 100.0, 'grams');
      await service.updateFoodQuantity('meal_dinner', 'rc_1', 200.0, 'grams');

      final todayLog = service.getTodayNutrition();
      final dinnerMeal = todayLog.meals.firstWhere(
        (m) => m.id == 'meal_dinner' || m.name.toLowerCase() == 'dinner',
      );

      expect(dinnerMeal.consumedFoods.first.quantity, equals(200.0));
      expect(todayLog.dailyCalories, closeTo(260.0, 0.01));
      expect(todayLog.dailyCarbohydrates, closeTo(56.0, 0.01));
    });

    test('removeFoodFromMeal removes food item and recalculates macros', () async {
      const paneer = FoodItem(
        id: 'pnr_1',
        name: 'Paneer',
        calories: 265.0,
        protein: 18.3,
        carbohydrates: 1.2,
        fats: 20.8,
      );

      await service.addFoodToMeal('meal_snack', paneer, 100.0, 'grams');
      await service.removeFoodFromMeal('meal_snack', 'pnr_1');

      final todayLog = service.getTodayNutrition();
      final snackMeal = todayLog.meals.firstWhere(
        (m) => m.id == 'meal_snack' || m.name.toLowerCase() == 'snack',
      );

      expect(snackMeal.consumedFoods, isEmpty);
      expect(todayLog.dailyCalories, equals(0.0));
    });

    test('completeMeal toggles completed state', () async {
      await service.completeMeal('meal_breakfast', true);
      final todayLog = service.getTodayNutrition();

      final breakfastMeal = todayLog.meals.firstWhere(
        (m) => m.id == 'meal_breakfast' || m.name.toLowerCase() == 'breakfast',
      );

      expect(breakfastMeal.completed, isTrue);
      expect(todayLog.completedMeals, equals(1));
    });
  });
}
