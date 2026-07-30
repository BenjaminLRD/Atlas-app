import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import 'local_storage.dart';

/// Abstract interface for nutrition data operations.
abstract class NutritionRepository {
  // Legacy backward compatibility methods
  double getProteinConsumed();
  double getProteinGoal();
  Future<void> saveProteinConsumed(double value);
  Future<void> saveProteinGoal(double value);

  // Strongly-typed nutrition domain operations
  DailyNutrition getDailyNutrition(String date);
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition);
  MacroTarget getMacroTarget();
  Future<void> saveMacroTarget(MacroTarget target);
  Future<void> logFoodItem({
    required String date,
    required MealCategory category,
    required FoodItem foodItem,
  });
  Future<void> toggleMealCompletion({
    required String date,
    required String mealId,
  });
}

/// Default implementation of NutritionRepository backed by LocalStorage.
class LocalNutritionRepository implements NutritionRepository {
  @override
  double getProteinConsumed() {
    return LocalStorage.getProteinConsumed();
  }

  @override
  double getProteinGoal() {
    return LocalStorage.getProteinGoal();
  }

  @override
  Future<void> saveProteinConsumed(double value) async {
    await LocalStorage.saveProteinConsumed(value);
  }

  @override
  Future<void> saveProteinGoal(double value) async {
    await LocalStorage.saveProteinGoal(value);
  }

  @override
  DailyNutrition getDailyNutrition(String date) {
    return LocalStorage.getDailyNutrition(date);
  }

  @override
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    await LocalStorage.saveDailyNutrition(dailyNutrition);
  }

  @override
  MacroTarget getMacroTarget() {
    return LocalStorage.getMacroTarget();
  }

  @override
  Future<void> saveMacroTarget(MacroTarget target) async {
    await LocalStorage.saveMacroTarget(target);
  }

  @override
  Future<void> logFoodItem({
    required String date,
    required MealCategory category,
    required FoodItem foodItem,
  }) async {
    final daily = getDailyNutrition(date);
    final updatedMeals = daily.meals.map((meal) {
      if (meal.category == category) {
        final newItems = List<FoodItem>.from(meal.items)..add(foodItem);
        return meal.copyWith(items: newItems);
      }
      return meal;
    }).toList();

    final updatedDaily = daily.copyWith(meals: updatedMeals);
    await saveDailyNutrition(updatedDaily);
  }

  @override
  Future<void> toggleMealCompletion({
    required String date,
    required String mealId,
  }) async {
    final daily = getDailyNutrition(date);
    final updatedMeals = daily.meals.map((meal) {
      if (meal.id == mealId) {
        return meal.copyWith(isCompleted: !meal.isCompleted);
      }
      return meal;
    }).toList();

    final updatedDaily = daily.copyWith(meals: updatedMeals);
    await saveDailyNutrition(updatedDaily);
  }
}
