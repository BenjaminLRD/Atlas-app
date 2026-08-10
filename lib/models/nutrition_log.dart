import 'meal_entry.dart';

/// Data model representing a daily nutrition tracking log.
class NutritionLog {
  final String id;
  final DateTime date;
  final List<MealEntry> meals;
  final double calorieGoal;
  final double proteinGoal;
  final double carbohydrateGoal;
  final double fatGoal;

  const NutritionLog({
    required this.id,
    required this.date,
    this.meals = const [],
    this.calorieGoal = 2200.0,
    this.proteinGoal = 150.0,
    this.carbohydrateGoal = 250.0,
    this.fatGoal = 70.0,
  });

  /// Computed total daily calories consumed across logged meals
  double get dailyCalories {
    return meals.fold(0.0, (sum, meal) => sum + meal.totalCalories);
  }

  /// Computed total daily protein consumed in grams
  double get dailyProtein {
    return meals.fold(0.0, (sum, meal) => sum + meal.totalProtein);
  }

  /// Computed total daily carbohydrates consumed in grams
  double get dailyCarbohydrates {
    return meals.fold(0.0, (sum, meal) => sum + meal.totalCarbohydrates);
  }

  /// Computed total daily fats consumed in grams
  double get dailyFats {
    return meals.fold(0.0, (sum, meal) => sum + meal.totalFats);
  }

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
      calorieGoal: (json['calorieGoal'] as num?)?.toDouble() ?? 2200.0,
      proteinGoal: (json['proteinGoal'] as num?)?.toDouble() ?? 150.0,
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
