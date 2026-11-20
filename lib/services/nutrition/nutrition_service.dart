import '../../models/consumed_food.dart';
import '../../models/daily_nutrition.dart';
import '../../models/food_item.dart';
import '../../models/macro_target.dart';
import '../../models/meal_entry.dart';
import '../../models/nutrition_log.dart';
import '../../models/nutrition_totals.dart';
import '../../data/nutrition_repository.dart';
import '../../data/food_repository.dart';
import 'nutrition_calculator.dart';
import 'nutrition_changes.dart';

/// High-level service managing nutrition state and persistence.
class NutritionService {
  final NutritionRepository _repository;
  final FoodRepository _foodRepository;

  NutritionService([
    NutritionRepository? repository,
    FoodRepository? foodRepository,
  ]) : _repository = repository ?? LocalNutritionRepository(),
       _foodRepository = foodRepository ?? LocalFoodRepository();

  /// Retrieve FoodRepository instance
  FoodRepository get foodRepository => _foodRepository;

  /// Retrieve all food items from food repository
  List<FoodItem> getAvailableFoods() => _foodRepository.getAllFoods();

  /// Search foods by query string and optional category filter
  List<FoodItem> searchFoods(String query, [String? category]) =>
      _foodRepository.searchFoods(query, category: category);

  /// Get foods by macro category
  List<FoodItem> getFoodsByCategory(String category) =>
      _foodRepository.searchFoods('', category: category);

  /// Get recent foods
  List<FoodItem> getRecentFoods() => _foodRepository.getRecentFoods();

  /// Get favorite foods
  List<FoodItem> getFavoriteFoods() => _foodRepository.getFavoriteFoods();

  /// Get scanned foods
  List<FoodItem> getScannedFoods() => _foodRepository.getScannedFoods();

  /// Search food by barcode (checks cache -> fetches API -> saves cache)
  Future<FoodItem?> searchByBarcode(String barcode) =>
      _foodRepository.searchByBarcode(barcode);

  /// Fetch remote food from API by barcode
  Future<FoodItem?> fetchRemoteFood(String barcode) =>
      _foodRepository.fetchRemoteFood(barcode);

  /// Save scanned food item locally
  Future<void> saveScannedFood(FoodItem food) async {
    await _foodRepository.saveScannedFood(food);
    NutritionChanges.instance.notifyChanged();
  }

  /// Add a custom food item
  Future<void> addCustomFood(FoodItem food) async {
    await _foodRepository.addCustomFood(food);
    NutritionChanges.instance.notifyChanged();
  }

  /// Create a custom food item (alias)
  Future<void> createCustomFood(FoodItem food) async {
    await addCustomFood(food);
  }

  /// Update a custom food item
  Future<void> updateCustomFood(FoodItem food) async {
    await _foodRepository.updateCustomFood(food);
    NutritionChanges.instance.notifyChanged();
  }

  /// Delete a custom food item
  Future<void> deleteCustomFood(String foodId) async {
    await _foodRepository.deleteCustomFood(foodId);
    NutritionChanges.instance.notifyChanged();
  }

  /// Toggle favorite status of a food item
  Future<void> toggleFavoriteFood(String foodId) async {
    await _foodRepository.toggleFavorite(foodId);
    NutritionChanges.instance.notifyChanged();
  }

  /// Record a food in recent list
  Future<void> recordRecentFood(String foodId) async {
    await _foodRepository.recordRecentFood(foodId);
    NutritionChanges.instance.notifyChanged();
  }

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
    NutritionChanges.instance.notifyChanged();
  }

  /// Legacy: Persist updated target protein goal
  Future<void> saveProteinGoal(double value) async {
    await _repository.saveProteinGoal(value);
    NutritionChanges.instance.notifyChanged();
  }

  /// Retrieve full daily nutrition state for a given date (defaults to today)
  DailyNutrition getDailyNutrition([String? date]) {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return _repository.getDailyNutrition(targetDate);
  }

  /// Persist daily nutrition state
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    await _repository.saveDailyNutrition(dailyNutrition);
    NutritionChanges.instance.notifyChanged();
  }

  /// Get current macro target goals
  MacroTarget getMacroTarget() {
    return _repository.getMacroTarget();
  }

  /// Update and save macro target goals
  Future<void> saveMacroTarget(MacroTarget target) async {
    await _repository.saveMacroTarget(target);
    NutritionChanges.instance.notifyChanged();
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
    NutritionChanges.instance.notifyChanged();
  }

  /// Toggle completion state of a meal entry
  Future<void> toggleMealCompletion({
    String? date,
    required String mealId,
  }) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    await _repository.toggleMealCompletion(date: targetDate, mealId: mealId);
    NutritionChanges.instance.notifyChanged();
  }

  // --- Nutrition Tracking System Methods ---

  /// Retrieve today's NutritionLog
  NutritionLog getTodayNutrition() {
    return _repository.getTodayNutritionLog();
  }

  /// The log for a local day (yyyy-MM-dd, default today). A day with nothing
  /// logged gives an empty log, never a made-up one.
  NutritionLog getNutritionLog([String? date]) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (date == null || date == today) return getTodayNutrition();
    for (final log in getNutritionHistory()) {
      if (log.date.toIso8601String().split('T')[0] == date) return log;
    }
    return NutritionLog(
      id: 'log_$date',
      date: DateTime.tryParse(date) ?? DateTime.now(),
    );
  }

  /// Consumed calories and macros for a day, summed from the logged meals.
  /// The one source for "how much did I eat": providers, screens and the AI
  /// tools all read this (or the same log's `totals`).
  NutritionTotals getConsumedTotals([String? date]) =>
      getNutritionLog(date).totals;

  /// [getDailyNutrition] (targets and plan) with that day's logged food counted
  /// as consumed, for callers that read consumed amounts from a DailyNutrition.
  /// Read-only: do not save it.
  DailyNutrition getDailyNutritionWithLogged([String? date]) =>
      getDailyNutrition(date).withLogged(getConsumedTotals(date));

  /// Retrieve full nutrition log history
  List<NutritionLog> getNutritionHistory() {
    return _repository.getNutritionLogHistory();
  }

  bool _matchesMeal(MealEntry meal, String mealId) {
    final mId = mealId.toLowerCase().trim();
    final mealName = meal.name.toLowerCase().trim();
    final entryId = meal.id.toLowerCase().trim();

    if (meal.id == mealId || mealName == mId || entryId == mId) return true;
    if (mId.contains('breakfast') &&
        (entryId.contains('breakfast') || mealName.contains('breakfast'))) {
      return true;
    }
    if (mId.contains('lunch') &&
        (entryId.contains('lunch') || mealName.contains('lunch'))) {
      return true;
    }
    if (mId.contains('dinner') &&
        (entryId.contains('dinner') || mealName.contains('dinner'))) {
      return true;
    }
    if (mId.contains('snack') &&
        (entryId.contains('snack') || mealName.contains('snack'))) {
      return true;
    }
    return false;
  }

  /// Add a FoodItem with quantity & unit to a specific meal
  Future<void> addFoodToMeal(
    String mealId,
    FoodItem food, [
    double quantity = 100.0,
    String unit = 'grams',
  ]) async {
    // Grams and millilitres are never interchangeable: refuse a quantity
    // that does not fit the food's per-100 g / per-100 ml basis.
    if (!NutritionCalculator.isUnitCompatible(food, unit)) {
      throw ArgumentError.value(
        unit,
        'unit',
        '${food.name} is measured per ${food.nutritionBasis.name}, '
            'so it cannot be logged in this unit',
      );
    }
    final currentLog = getTodayNutrition();
    final newConsumed = ConsumedFood(
      food: food,
      quantity: quantity,
      unit: unit,
    );

    final updatedMeals = currentLog.meals.map((meal) {
      if (_matchesMeal(meal, mealId)) {
        final updatedConsumed = List<ConsumedFood>.from(meal.consumedFoods)
          ..add(newConsumed);
        return meal.copyWith(consumedFoods: updatedConsumed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    await _foodRepository.recordRecentFood(food.id);
    NutritionChanges.instance.notifyChanged();
  }

  /// Remove a food item by foodId from a specific meal
  Future<void> removeFoodFromMeal(String mealId, String foodId) async {
    final currentLog = getTodayNutrition();

    final updatedMeals = currentLog.meals.map((meal) {
      if (_matchesMeal(meal, mealId)) {
        final updatedConsumed = meal.consumedFoods
            .where((cf) => cf.food.id != foodId)
            .toList();
        return meal.copyWith(consumedFoods: updatedConsumed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    NutritionChanges.instance.notifyChanged();
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
      if (_matchesMeal(meal, mealId)) {
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
    NutritionChanges.instance.notifyChanged();
  }

  /// Complete or uncomplete a specific meal
  Future<void> completeMeal(String mealId, [bool completed = true]) async {
    final currentLog = getTodayNutrition();

    final updatedMeals = currentLog.meals.map((meal) {
      if (meal.id == mealId ||
          meal.name.toLowerCase() == mealId.toLowerCase()) {
        return meal.copyWith(completed: completed, isCompleted: completed);
      }
      return meal;
    }).toList();

    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _repository.saveNutritionLog(updatedLog);
    NutritionChanges.instance.notifyChanged();
  }
}
