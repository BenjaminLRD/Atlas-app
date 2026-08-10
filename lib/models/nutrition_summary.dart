import 'package:flutter/foundation.dart';

/// Analytics summary layer for aggregate nutrition metrics
@immutable
class NutritionSummary {
  final double totalCaloriesConsumed;
  final double averageDailyCalories;
  final double averageProtein;
  final double averageCarbohydrates;
  final double averageFats;
  final double proteinGoalHitPercentage;
  final double calorieGoalConsistency;
  final int currentNutritionStreak;
  final List<double> weeklyCalories;
  final Map<String, double> macroBalance;

  const NutritionSummary({
    this.totalCaloriesConsumed = 0.0,
    this.averageDailyCalories = 0.0,
    this.averageProtein = 0.0,
    this.averageCarbohydrates = 0.0,
    this.averageFats = 0.0,
    this.proteinGoalHitPercentage = 0.0,
    this.calorieGoalConsistency = 0.0,
    this.currentNutritionStreak = 0,
    this.weeklyCalories = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.macroBalance = const {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0},
  });

  /// Factory empty default summary
  factory NutritionSummary.empty() {
    return const NutritionSummary();
  }

  NutritionSummary copyWith({
    double? totalCaloriesConsumed,
    double? averageDailyCalories,
    double? averageProtein,
    double? averageCarbohydrates,
    double? averageFats,
    double? proteinGoalHitPercentage,
    double? calorieGoalConsistency,
    int? currentNutritionStreak,
    List<double>? weeklyCalories,
    Map<String, double>? macroBalance,
  }) {
    return NutritionSummary(
      totalCaloriesConsumed: totalCaloriesConsumed ?? this.totalCaloriesConsumed,
      averageDailyCalories: averageDailyCalories ?? this.averageDailyCalories,
      averageProtein: averageProtein ?? this.averageProtein,
      averageCarbohydrates: averageCarbohydrates ?? this.averageCarbohydrates,
      averageFats: averageFats ?? this.averageFats,
      proteinGoalHitPercentage: proteinGoalHitPercentage ?? this.proteinGoalHitPercentage,
      calorieGoalConsistency: calorieGoalConsistency ?? this.calorieGoalConsistency,
      currentNutritionStreak: currentNutritionStreak ?? this.currentNutritionStreak,
      weeklyCalories: weeklyCalories ?? this.weeklyCalories,
      macroBalance: macroBalance ?? this.macroBalance,
    );
  }

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    final rawWeekly = json['weeklyCalories'] as List<dynamic>?;
    final parsedWeekly = rawWeekly != null
        ? rawWeekly.map((e) => (e as num).toDouble()).toList()
        : const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

    final rawMacro = json['macroBalance'] as Map<String, dynamic>?;
    final parsedMacro = rawMacro != null
        ? rawMacro.map((k, v) => MapEntry(k, (v as num).toDouble()))
        : const {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0};

    return NutritionSummary(
      totalCaloriesConsumed: (json['totalCaloriesConsumed'] as num?)?.toDouble() ?? 0.0,
      averageDailyCalories: (json['averageDailyCalories'] as num?)?.toDouble() ?? 0.0,
      averageProtein: (json['averageProtein'] as num?)?.toDouble() ?? 0.0,
      averageCarbohydrates: (json['averageCarbohydrates'] as num?)?.toDouble() ?? 0.0,
      averageFats: (json['averageFats'] as num?)?.toDouble() ?? 0.0,
      proteinGoalHitPercentage: (json['proteinGoalHitPercentage'] as num?)?.toDouble() ?? 0.0,
      calorieGoalConsistency: (json['calorieGoalConsistency'] as num?)?.toDouble() ?? 0.0,
      currentNutritionStreak: (json['currentNutritionStreak'] as num?)?.toInt() ?? 0,
      weeklyCalories: parsedWeekly,
      macroBalance: parsedMacro,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCaloriesConsumed': totalCaloriesConsumed,
      'averageDailyCalories': averageDailyCalories,
      'averageProtein': averageProtein,
      'averageCarbohydrates': averageCarbohydrates,
      'averageFats': averageFats,
      'proteinGoalHitPercentage': proteinGoalHitPercentage,
      'calorieGoalConsistency': calorieGoalConsistency,
      'currentNutritionStreak': currentNutritionStreak,
      'weeklyCalories': weeklyCalories,
      'macroBalance': macroBalance,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionSummary &&
        other.totalCaloriesConsumed == totalCaloriesConsumed &&
        other.averageDailyCalories == averageDailyCalories &&
        other.averageProtein == averageProtein &&
        other.averageCarbohydrates == averageCarbohydrates &&
        other.averageFats == averageFats &&
        other.proteinGoalHitPercentage == proteinGoalHitPercentage &&
        other.calorieGoalConsistency == calorieGoalConsistency &&
        other.currentNutritionStreak == currentNutritionStreak &&
        listEquals(other.weeklyCalories, weeklyCalories) &&
        mapEquals(other.macroBalance, macroBalance);
  }

  @override
  int get hashCode {
    return Object.hash(
      totalCaloriesConsumed,
      averageDailyCalories,
      averageProtein,
      averageCarbohydrates,
      averageFats,
      proteinGoalHitPercentage,
      calorieGoalConsistency,
      currentNutritionStreak,
      Object.hashAll(weeklyCalories),
      Object.hashAll(macroBalance.entries),
    );
  }
}
