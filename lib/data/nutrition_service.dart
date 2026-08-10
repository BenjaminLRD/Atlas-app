import '../models/consumed_food.dart';
import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_log.dart';
import '../providers/fitness_provider.dart';
import 'mock_food_database.dart';
import 'nutrition_repository.dart';

/// High-level service managing nutrition state and persistence.
class NutritionService {
  final NutritionRepository _repository;

  NutritionService([NutritionRepository? repository])
      : _repository = repository ?? LocalNutritionRepository();

  /// Retrieve all food items from mock food database
  List<FoodItem> getAvailableFoods() => MockFoodDatabase.getAllFoods();

  /// Search foods by query string
  List<FoodItem> searchFoods(String query) => MockFoodDatabase.searchFoods(query);

  /// Get foods by macro category
  List<FoodItem> getFoodsByCategory(String category) =>
      MockFoodDatabase.getFoodsByCategory(category);

  /// Legacy: Get current protein consumed today
  double getProteinConsumed() {
    return _repository.getProteinConsumed();
  }

  /// Legacy: Get daily target protein goal
  double getProteinGoal() {
    return _repository.getProteinGoal();
  }

  /// Legacy: Persist updated protein consumed
  Future<void> saveProteinConsumed(double value) async {
    await _repository.saveProteinConsumed(value);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Legacy: Persist updated target protein goal
  Future<void> saveProteinGoal(double value) async {
    await _repository.saveProteinGoal(value);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Retrieve full daily nutrition state for a given date (defaults to today)
  DailyNutrition getDailyNutrition([String? date]) {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return _repository.getDailyNutrition(targetDate);
  }

  /// Persist daily nutrition state
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    await _repository.saveDailyNutrition(dailyNutrition);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Get current macro target goals
  MacroTarget getMacroTarget() {
    return _repository.getMacroTarget();
  }

  /// Update and save macro target goals
  Future<void> saveMacroTarget(MacroTarget target) async {
    await _repository.saveMacroTarget(target);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Add a food item entry to a meal category for a date
  Future<void> logFoodItem({
    String? date,
    required MealCategory category,
    required FoodItem foodItem,
  }) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    await _repository.logFoodItem(
      date: targetDate,
      category: category,
      foodItem: foodItem,
    );
    FitnessProvider.instance.refreshNutrition();
  }

  /// Toggle completion state of a meal entry
  Future<void> toggleMealCompletion({
    String? date,
    required String mealId,
  }) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    await _repository.toggleMealCompletion(
      date: targetDate,
      mealId: mealId,
    );
    FitnessProvider.instance.refreshNutrition();
  }

  // --- Nutrition Tracking System Methods ---

  /// Retrieve today's NutritionLog
  NutritionLog getTodayNutrition() {
    return _repository.getTodayNutritionLog();
  }

  /// Retrieve full nutrition log history
  List<NutritionLog> getNutritionHistory() {
    return _repository.getNutritionLogHistory();
  }

  /// Add a FoodItem with quantity & unit to a specific meal
  Future<void> addFoodToMeal(
    String mealId,
    FoodItem food, [
    double quantity = 100.0,
    String unit = 'grams',
  ]) async {
    final currentLog = getTodayNutrition();
    final newConsumed = ConsumedFood(food: food, quantity: quantity, unit: unit);

    final updatedMeals = currentLog.meals.map((meal) {
      if (meal.id == mealId || meal.name.toLowerCase() == mealId.toLowerCase()) {
        final updatedConsumed = List<ConsumedFood>.from(meal.consumedFoods)..add(newConsumed);
        return meal.copyWith(consumedFoods: updatedConsumed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Remove a food item by foodId from a specific meal
  Future<void> removeFoodFromMeal(String mealId, String foodId) async {
    final currentLog = getTodayNutrition();

    final updatedMeals = currentLog.meals.map((meal) {
      if (meal.id == mealId || meal.name.toLowerCase() == mealId.toLowerCase()) {
        final updatedConsumed = meal.consumedFoods
            .where((cf) => cf.food.id != foodId)
            .toList();
        return meal.copyWith(consumedFoods: updatedConsumed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Update food portion quantity and unit in a specific meal
  Future<void> updateFoodQuantity(
    String mealId,
    String foodId,
    double quantity, [
    String unit = 'grams',
  ]) async {
    final currentLog = getTodayNutrition();

    final updatedMeals = currentLog.meals.map((meal) {
      if (meal.id == mealId || meal.name.toLowerCase() == mealId.toLowerCase()) {
        final updatedConsumed = meal.consumedFoods.map((cf) {
          if (cf.food.id == foodId) {
            return cf.copyWith(quantity: quantity, unit: unit);
          }
          return cf;
        }).toList();
        return meal.copyWith(consumedFoods: updatedConsumed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    FitnessProvider.instance.refreshNutrition();
  }

  /// Complete or uncomplete a specific meal
  Future<void> completeMeal(String mealId, [bool completed = true]) async {
    final currentLog = getTodayNutrition();

    final updatedMeals = currentLog.meals.map((meal) {
      if (meal.id == mealId || meal.name.toLowerCase() == mealId.toLowerCase()) {
        return meal.copyWith(completed: completed, isCompleted: completed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    FitnessProvider.instance.refreshNutrition();
  }
}
