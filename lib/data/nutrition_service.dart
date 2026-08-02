import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import '../providers/fitness_provider.dart';
import 'nutrition_repository.dart';

/// High-level service managing nutrition state and persistence.
class NutritionService {
  final NutritionRepository _repository;

  NutritionService([NutritionRepository? repository])
      : _repository = repository ?? LocalNutritionRepository();

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
}
