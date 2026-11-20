import 'meal_entry.dart';
import 'nutrition_totals.dart';

/// Data model representing a daily nutrition tracking log.
class NutritionLog {
  final String id;
  final DateTime date;
  final List<MealEntry> meals;
  final double calorieGoal;
  final double proteinGoal;
  final double carbohydrateGoal;
  final double fatGoal;

  /// Values the goals take when nothing was set. Nothing in the app writes
  /// the goals, so a log whose goals equal these cannot be told apart from
  /// one that never had goals.
  static const double defaultCalorieGoal = 2200.0;
  static const double defaultProteinGoal = 150.0;

  const NutritionLog({
    required this.id,
    required this.date,
    this.meals = const [],
    this.calorieGoal = defaultCalorieGoal,
    this.proteinGoal = defaultProteinGoal,
    this.carbohydrateGoal = 250.0,
    this.fatGoal = 70.0,
  });

  /// Consumed calories and macros for the day: the single calculation every
  /// screen and provider getter reads.
  NutritionTotals get totals => NutritionTotals.fromMeals(meals);

  /// Computed total daily calories consumed across logged meals
  double get dailyCalories => totals.calories;

  /// How many logged items have unknown calories ([dailyCalories] is then a
  /// minimum).
  int get unknownCalorieItems => totals.unknownCalorieItems;

  /// [dailyCalories] as shown: "190", "190+" when it is a minimum, or a dash
  /// when no food gave calories.
  String get dailyCaloriesLabel => totals.caloriesLabel;

  /// The macros as shown, like [dailyCaloriesLabel] (without the unit).
  String get dailyProteinLabel => totals.proteinLabel;
  String get dailyCarbohydratesLabel => totals.carbsLabel;
  String get dailyFatsLabel => totals.fatLabel;

  int get unknownProteinItems => totals.unknownProteinItems;
  int get unknownCarbItems => totals.unknownCarbItems;
  int get unknownFatItems => totals.unknownFatItems;

  /// Computed total daily protein consumed in grams
  double get dailyProtein => totals.protein;

  /// Computed total daily carbohydrates consumed in grams
  double get dailyCarbohydrates => totals.carbs;

  /// Computed total daily fats consumed in grams
  double get dailyFats => totals.fat;

  /// Total count of completed meals for the day
  int get completedMeals {
    return meals.where((m) => m.completed || m.isCompleted).length;
  }

  /// Calorie goal completion progress ratio [0.0 - 1.0]
  double get calorieProgress {
    if (calorieGoal <= 0) return 0.0;
    return (dailyCalories / calorieGoal).clamp(0.0, 1.0);
  }

  /// Protein goal completion progress ratio [0.0 - 1.0]
  double get proteinProgress {
    if (proteinGoal <= 0) return 0.0;
    return (dailyProtein / proteinGoal).clamp(0.0, 1.0);
  }

  /// Carbohydrate goal completion progress ratio [0.0 - 1.0]
  double get carbohydrateProgress {
    if (carbohydrateGoal <= 0) return 0.0;
    return (dailyCarbohydrates / carbohydrateGoal).clamp(0.0, 1.0);
  }

  /// Fat goal completion progress ratio [0.0 - 1.0]
  double get fatProgress {
    if (fatGoal <= 0) return 0.0;
    return (dailyFats / fatGoal).clamp(0.0, 1.0);
  }

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List?;
    final mealList = rawMeals != null
        ? rawMeals
              .map((e) => MealEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <MealEntry>[];

    return NutritionLog(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      meals: mealList,
      calorieGoal:
          (json['calorieGoal'] as num?)?.toDouble() ?? defaultCalorieGoal,
      proteinGoal:
          (json['proteinGoal'] as num?)?.toDouble() ?? defaultProteinGoal,
      carbohydrateGoal: (json['carbohydrateGoal'] as num?)?.toDouble() ?? 250.0,
      fatGoal: (json['fatGoal'] as num?)?.toDouble() ?? 70.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'meals': meals.map((e) => e.toJson()).toList(),
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'carbohydrateGoal': carbohydrateGoal,
      'fatGoal': fatGoal,
      'dailyCalories': dailyCalories,
      'dailyProtein': dailyProtein,
      'dailyCarbohydrates': dailyCarbohydrates,
      'dailyFats': dailyFats,
      'completedMeals': completedMeals,
    };
  }

  NutritionLog copyWith({
    String? id,
    DateTime? date,
    List<MealEntry>? meals,
    double? calorieGoal,
    double? proteinGoal,
    double? carbohydrateGoal,
    double? fatGoal,
  }) {
    return NutritionLog(
      id: id ?? this.id,
      date: date ?? this.date,
      meals: meals ?? List.from(this.meals),
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbohydrateGoal: carbohydrateGoal ?? this.carbohydrateGoal,
      fatGoal: fatGoal ?? this.fatGoal,
    );
  }
}
