import '../../../data/food_repository.dart';
import '../../../data/local_storage.dart';
import '../../nutrition/nutrition_service.dart';
import 'ai_tool.dart';

/// AI Agent tool for querying nutrition telemetry, suggesting meals, and adjusting nutrition targets.
class NutritionTool extends AITool {
  final NutritionService _nutritionService;
  final FoodRepository _foodRepository;

  NutritionTool({
    NutritionService? nutritionService,
    FoodRepository? foodRepository,
  }) : _nutritionService = nutritionService ?? NutritionService(),
       _foodRepository = foodRepository ?? LocalFoodRepository();

  @override
  String get name => 'nutrition_tool';

  @override
  String get description =>
      'Retrieves today\'s calorie and protein intake, generates tailored meal suggestions, and adjusts athlete weight goal calories.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'OBJECT',
    'properties': {
      'action': {
        'type': 'STRING',
        'enum': [
          'get_today_calories',
          'get_protein_intake',
          'generate_meal_suggestion',
          'adjust_weight_goal_calories',
        ],
        'description': 'The nutrition action to perform.',
      },
      'meal_type': {
        'type': 'STRING',
        'enum': ['breakfast', 'lunch', 'dinner', 'snack', 'post_workout'],
        'description': 'Type of meal to generate a suggestion for.',
      },
      'target_calories': {
        'type': 'NUMBER',
        'description':
            'Target calories for meal generation or daily adjustment.',
      },
      'high_protein': {
        'type': 'BOOLEAN',
        'description':
            'Whether the meal suggestion should prioritize high protein.',
      },
      'reason': {
        'type': 'STRING',
        'description': 'Rationale for adjusting daily calorie goals.',
      },
      'confirmed': {
        'type': 'BOOLEAN',
        'description':
            'Explicit athlete confirmation flag for goal adjustments.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final action = arguments['action'] as String? ?? 'get_today_calories';

    switch (action) {
      case 'get_today_calories':
        return _getTodayCalories();
      case 'get_protein_intake':
        return _getProteinIntake();
      case 'generate_meal_suggestion':
        return _generateMealSuggestion(arguments);
      case 'adjust_weight_goal_calories':
        return _adjustWeightGoalCalories(arguments);
      default:
        return {'status': 'error', 'message': 'Unknown action: $action'};
    }
  }

  Map<String, dynamic> _getTodayCalories() {
    final daily = _nutritionService.getDailyNutritionWithLogged();
    final targetCalories = daily.targets.calories > 0
        ? daily.targets.calories
        : 2400.0;
    final consumed = daily.totalCaloriesConsumed;
    final remaining = (targetCalories - consumed).clamp(0.0, double.infinity);
    final unknown = daily.unknownCalorieItems;

    return {
      'status': 'success',
      'action': 'get_today_calories',
      'consumed_calories': consumed.round(),
      'calories_are_lower_bound': unknown > 0,
      'unknown_calorie_items': unknown,
      if (unknown > 0)
        'calorie_note':
            '$unknown logged item(s) have unknown calories, so '
            'consumed_calories is a minimum and remaining_calories a maximum. '
            'Those items are not 0 kcal.',
      'target_calories': targetCalories.round(),
      'remaining_calories': remaining.round(),
      'progress_percent': targetCalories > 0
          ? ((consumed / targetCalories) * 100).round()
          : 0,
      'is_surplus': consumed > targetCalories,
    };
  }

  Map<String, dynamic> _getProteinIntake() {
    final daily = _nutritionService.getDailyNutritionWithLogged();
    final targetProtein = daily.targets.proteinGrams > 0
        ? daily.targets.proteinGrams
        : 160.0;
    final consumed = daily.totalProteinConsumed;
    final remaining = (targetProtein - consumed).clamp(0.0, double.infinity);
    final unknown = daily.totalsConsumed.unknownProteinItems;

    return {
      'status': 'success',
      'action': 'get_protein_intake',
      'consumed_protein_g': consumed.round(),
      'protein_is_lower_bound': unknown > 0,
      'unknown_protein_items': unknown,
      if (unknown > 0)
        'protein_note':
            '$unknown logged item(s) have unknown protein, so '
            'consumed_protein_g is a minimum and remaining_protein_g a '
            'maximum. Those items are not 0 g.',
      'target_protein_g': targetProtein.round(),
      'remaining_protein_g': remaining.round(),
      'progress_percent': targetProtein > 0
          ? ((consumed / targetProtein) * 100).round()
          : 0,
    };
  }

  Map<String, dynamic> _generateMealSuggestion(Map<String, dynamic> args) {
    final mealType = (args['meal_type'] as String? ?? 'post_workout')
        .toLowerCase();
    final highProtein = args['high_protein'] != false;

    final foods = _foodRepository.getAllFoods();
    final matchingFoods = foods.where((f) {
      if (highProtein && f.protein < 15.0) return false;
      return true;
    }).toList();

    final selected = matchingFoods.isNotEmpty
        ? matchingFoods.take(3).toList()
        : foods.take(3).toList();

    return {
      'status': 'success',
      'action': 'generate_meal_suggestion',
      'meal_type': mealType,
      'recommended_items': selected
          .map(
            (f) => {
              'name': f.name,
              'calories': f.calories.round(),
              'protein_g': f.protein.round(),
              'carbs_g': f.carbohydrates.round(),
              'fats_g': f.fats.round(),
              'serving': f.servingSize,
            },
          )
          .toList(),
      'total_meal_protein': selected
          .fold<double>(0, (sum, f) => sum + f.protein)
          .round(),
      'total_meal_calories': selected
          .fold<double>(0, (sum, f) => sum + f.calories)
          .round(),
    };
  }

  Future<Map<String, dynamic>> _adjustWeightGoalCalories(
    Map<String, dynamic> args,
  ) async {
    final newCalories = (args['target_calories'] as num?)?.toDouble() ?? 2500.0;
    final reason =
        args['reason'] as String? ?? 'Optimization based on energy output';
    final isConfirmed = args['confirmed'] == true;

    final currentGoal = LocalStorage.getWeightGoal();
    final currentTarget = currentGoal?.dailyCalorieTarget ?? 2400.0;

    if (!isConfirmed) {
      return {
        'status': 'confirmation_required',
        'action': 'adjust_weight_goal_calories',
        'requires_confirmation': true,
        'prompt':
            'Adjust your daily calorie target from ${currentTarget.round()} kcal to ${newCalories.round()} kcal ($reason)?',
        'payload': {'target_calories': newCalories, 'reason': reason},
      };
    }

    if (currentGoal != null) {
      final updated = currentGoal.copyWith(dailyCalorieTarget: newCalories);
      await LocalStorage.saveWeightGoal(updated);
    }

    return {
      'status': 'success',
      'action': 'adjust_weight_goal_calories',
      'previous_calories': currentTarget.round(),
      'new_calories': newCalories.round(),
      'message':
          'Daily target successfully updated to ${newCalories.round()} kcal/day!',
    };
  }
}
