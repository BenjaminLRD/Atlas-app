import '../../models/daily_nutrition.dart';
import '../../models/food_item.dart';
import '../../models/macro_target.dart';
import '../../models/meal_entry.dart';
import '../../models/nutrition_log.dart';
import '../local_storage.dart';
import '../nutrition_repository.dart';

/// Production offline-first local repository for nutrition tracking and meal logs.
/// Saves instantly to local storage. Cloud upload is done by
/// `CloudNutritionRepository`, which extends this class.
class NutritionLocalRepository implements NutritionRepository {
  @override
  double getProteinConsumed() => LocalStorage.getProteinConsumed();

  @override
  double getProteinGoal() => LocalStorage.getProteinGoal();

  @override
  Future<void> saveProteinConsumed(double value) async {
    await LocalStorage.saveProteinConsumed(value);
  }

  @override
  Future<void> saveProteinGoal(double value) async {
    await LocalStorage.saveProteinGoal(value);
  }

  @override
  DailyNutrition getDailyNutrition(String date, {String? userId}) {
    return LocalStorage.getDailyNutrition(date, userId: userId);
  }

  @override
  Future<void> saveDailyNutrition(
    DailyNutrition dailyNutrition, {
    String userId = 'usr_local_01',
  }) async {
    await LocalStorage.saveDailyNutrition(dailyNutrition, userId: userId);
  }

  @override
  MacroTarget getMacroTarget() => LocalStorage.getMacroTarget();

  @override
  Future<void> saveMacroTarget(MacroTarget target) async {
    await LocalStorage.saveMacroTarget(target);
  }

  @override
  Future<void> logFoodItem({
    required String date,
    required MealCategory category,
    required FoodItem foodItem,
    String userId = 'usr_local_01',
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
    await saveDailyNutrition(updatedDaily, userId: userId);
  }

  @override
  Future<void> toggleMealCompletion({
    required String date,
    required String mealId,
    String userId = 'usr_local_01',
  }) async {
    final daily = getDailyNutrition(date);
    final updatedMeals = daily.meals.map((meal) {
      if (meal.id == mealId) {
        return meal.copyWith(isCompleted: !meal.isCompleted);
      }
      return meal;
    }).toList();

    final updatedDaily = daily.copyWith(meals: updatedMeals);
    await saveDailyNutrition(updatedDaily, userId: userId);
  }

  @override
  Future<void> saveNutritionLog(
    NutritionLog log, {
    String userId = 'usr_local_01',
  }) async {
    await LocalStorage.saveNutritionLog(log);
  }

  @override
  List<NutritionLog> getNutritionLogHistory() =>
      LocalStorage.getNutritionLogHistory();

  @override
  NutritionLog getTodayNutritionLog() => LocalStorage.getTodayNutritionLog();
}
