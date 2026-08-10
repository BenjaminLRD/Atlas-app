import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/data/nutrition_repository.dart';
import 'package:aizawl_gym/data/nutrition_service.dart';
import 'package:aizawl_gym/models/daily_nutrition.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/macro_target.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_log.dart';

class FakeNutritionRepository implements NutritionRepository {
  double _proteinConsumed = 120.0;
  double _proteinGoal = 160.0;
  MacroTarget _macroTarget = MacroTarget.defaultTarget();
  final Map<String, DailyNutrition> _store = {};

  @override
  double getProteinConsumed() => _proteinConsumed;

  @override
  double getProteinGoal() => _proteinGoal;

  @override
  Future<void> saveProteinConsumed(double value) async {
    _proteinConsumed = value;
  }

  @override
  Future<void> saveProteinGoal(double value) async {
    _proteinGoal = value;
  }

  @override
  DailyNutrition getDailyNutrition(String date) {
    return _store[date] ?? DailyNutrition.defaultForDate(date, _macroTarget);
  }

  @override
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    _store[dailyNutrition.date] = dailyNutrition;
    _proteinConsumed = dailyNutrition.totalProteinConsumed;
  }

  @override
  MacroTarget getMacroTarget() => _macroTarget;

  @override
  Future<void> saveMacroTarget(MacroTarget target) async {
    _macroTarget = target;
    _proteinGoal = target.proteinGrams;
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
        return meal.copyWith(items: newItems, isCompleted: true);
      }
      return meal;
    }).toList();

    await saveDailyNutrition(daily.copyWith(meals: updatedMeals));
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

    await saveDailyNutrition(daily.copyWith(meals: updatedMeals));
  }

  @override
  Future<void> saveNutritionLog(NutritionLog log) async {}

  @override
  List<NutritionLog> getNutritionLogHistory() => [];

  @override
  NutritionLog getTodayNutritionLog() => NutritionLog(id: 'today', date: DateTime.now());
}

void main() {
  group('NutritionRepository & NutritionService Tests', () {
    late FakeNutritionRepository repository;
    late NutritionService service;

    setUp(() {
      repository = FakeNutritionRepository();
      service = NutritionService(repository);
    });

    test('NutritionService retrieves default daily nutrition', () {
      final daily = service.getDailyNutrition('2026-07-29');

      expect(daily.date, '2026-07-29');
      expect(daily.meals, isNotEmpty);
      expect(service.getProteinGoal(), 160.0);
    });

    test('NutritionService logs food item and updates daily macros', () async {
      const newFood = FoodItem(
        id: 'snack_extra',
        name: 'Greek Yogurt',
        calories: 150,
        proteinGrams: 20,
        carbsGrams: 8,
        fatGrams: 0,
      );

      final initialDaily = service.getDailyNutrition('2026-07-29');
      final initialProtein = initialDaily.totalProteinConsumed;

      await service.logFoodItem(
        date: '2026-07-29',
        category: MealCategory.snack,
        foodItem: newFood,
      );

      final updatedDaily = service.getDailyNutrition('2026-07-29');
      expect(updatedDaily.totalProteinConsumed, greaterThan(initialProtein));
    });

    test('NutritionService toggles meal completion', () async {
      final initialDaily = service.getDailyNutrition('2026-07-29');
      final targetMeal = initialDaily.meals.first;
      final initialStatus = targetMeal.isCompleted;

      await service.toggleMealCompletion(
        date: '2026-07-29',
        mealId: targetMeal.id,
      );

      final updatedDaily = service.getDailyNutrition('2026-07-29');
      final updatedMeal = updatedDaily.meals.firstWhere((m) => m.id == targetMeal.id);

      expect(updatedMeal.isCompleted, !initialStatus);
    });

    test('NutritionService saves macro target and synchronizes protein goal', () async {
      const newTarget = MacroTarget(
        calories: 3000.0,
        proteinGrams: 200.0,
        carbsGrams: 400.0,
        fatGrams: 80.0,
      );

      await service.saveMacroTarget(newTarget);

      expect(service.getMacroTarget().calories, 3000.0);
      expect(service.getProteinGoal(), 200.0);
    });
  });
}
