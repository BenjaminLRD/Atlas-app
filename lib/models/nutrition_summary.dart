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

  /// How many logged days were summarised, and how many of them had foods
  /// with an unknown value. Averages and rates use only the days that are
  /// complete for that nutrient, and [totalCaloriesConsumed] and
  /// [weeklyCalories] are minimums when any day is incomplete. All zero (the
  /// default) means nothing is unknown.
  final int daysCounted;
  final int unknownCalorieDays;
  final int unknownProteinDays;

  /// Days where protein, carbs or fat is incomplete (the macro balance uses
  /// only the other days).
  final int unknownMacroDays;

  /// For each of the 7 days in [weeklyCalories], true when that day's figure
  /// leaves out foods with unknown calories.
  final List<bool> weeklyCaloriesPartial;

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
    this.daysCounted = 0,
    this.unknownCalorieDays = 0,
    this.unknownProteinDays = 0,
    this.unknownMacroDays = 0,
    this.weeklyCaloriesPartial = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
  });

  /// False when no day has complete calories, so there is no average to show.
  bool get caloriesKnown =>
      daysCounted == 0 || unknownCalorieDays < daysCounted;

  /// False when no day has complete protein: there is no average or hit rate.
  bool get proteinKnown =>
      daysCounted == 0 || unknownProteinDays < daysCounted;

  /// False when no day has complete protein, carbs and fat: the macro split
  /// shown is not based on data.
  bool get macroBalanceKnown =>
      daysCounted == 0 || unknownMacroDays < daysCounted;

  /// True when any day left out foods with unknown calories or protein.
  bool get hasUnknownDays =>
      unknownCalorieDays > 0 || unknownProteinDays > 0 || unknownMacroDays > 0;

  /// Convenience aliases for AI coach briefs and UI cards
  double get proteinGrams => averageProtein;
  double get proteinTargetGrams => 160.0;
  double get totalCalories => totalCaloriesConsumed;

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
    int? daysCounted,
    int? unknownCalorieDays,
    int? unknownProteinDays,
    int? unknownMacroDays,
    List<bool>? weeklyCaloriesPartial,
  }) {
    return NutritionSummary(
      totalCaloriesConsumed:
          totalCaloriesConsumed ?? this.totalCaloriesConsumed,
      averageDailyCalories: averageDailyCalories ?? this.averageDailyCalories,
      averageProtein: averageProtein ?? this.averageProtein,
      averageCarbohydrates: averageCarbohydrates ?? this.averageCarbohydrates,
      averageFats: averageFats ?? this.averageFats,
      proteinGoalHitPercentage:
          proteinGoalHitPercentage ?? this.proteinGoalHitPercentage,
      calorieGoalConsistency:
          calorieGoalConsistency ?? this.calorieGoalConsistency,
      currentNutritionStreak:
          currentNutritionStreak ?? this.currentNutritionStreak,
      weeklyCalories: weeklyCalories ?? this.weeklyCalories,
      macroBalance: macroBalance ?? this.macroBalance,
      daysCounted: daysCounted ?? this.daysCounted,
      unknownCalorieDays: unknownCalorieDays ?? this.unknownCalorieDays,
      unknownProteinDays: unknownProteinDays ?? this.unknownProteinDays,
      unknownMacroDays: unknownMacroDays ?? this.unknownMacroDays,
      weeklyCaloriesPartial:
          weeklyCaloriesPartial ?? this.weeklyCaloriesPartial,
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
      totalCaloriesConsumed:
          (json['totalCaloriesConsumed'] as num?)?.toDouble() ?? 0.0,
      averageDailyCalories:
          (json['averageDailyCalories'] as num?)?.toDouble() ?? 0.0,
      averageProtein: (json['averageProtein'] as num?)?.toDouble() ?? 0.0,
      averageCarbohydrates:
          (json['averageCarbohydrates'] as num?)?.toDouble() ?? 0.0,
      averageFats: (json['averageFats'] as num?)?.toDouble() ?? 0.0,
      proteinGoalHitPercentage:
          (json['proteinGoalHitPercentage'] as num?)?.toDouble() ?? 0.0,
      calorieGoalConsistency:
          (json['calorieGoalConsistency'] as num?)?.toDouble() ?? 0.0,
      currentNutritionStreak:
          (json['currentNutritionStreak'] as num?)?.toInt() ?? 0,
      weeklyCalories: parsedWeekly,
      macroBalance: parsedMacro,
      daysCounted: (json['daysCounted'] as num?)?.toInt() ?? 0,
      unknownCalorieDays: (json['unknownCalorieDays'] as num?)?.toInt() ?? 0,
      unknownProteinDays: (json['unknownProteinDays'] as num?)?.toInt() ?? 0,
      unknownMacroDays: (json['unknownMacroDays'] as num?)?.toInt() ?? 0,
      weeklyCaloriesPartial: [
        for (var i = 0; i < 7; i++)
          i < ((json['weeklyCaloriesPartial'] as List?)?.length ?? 0) &&
              (json['weeklyCaloriesPartial'] as List)[i] == true,
      ],
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
      if (daysCounted > 0) 'daysCounted': daysCounted,
      if (unknownCalorieDays > 0) 'unknownCalorieDays': unknownCalorieDays,
      if (unknownProteinDays > 0) 'unknownProteinDays': unknownProteinDays,
      if (unknownMacroDays > 0) 'unknownMacroDays': unknownMacroDays,
      if (weeklyCaloriesPartial.any((p) => p))
        'weeklyCaloriesPartial': weeklyCaloriesPartial,
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
        mapEquals(other.macroBalance, macroBalance) &&
        other.daysCounted == daysCounted &&
        other.unknownCalorieDays == unknownCalorieDays &&
        other.unknownProteinDays == unknownProteinDays &&
        other.unknownMacroDays == unknownMacroDays &&
        listEquals(other.weeklyCaloriesPartial, weeklyCaloriesPartial);
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
      daysCounted,
      unknownCalorieDays,
      unknownProteinDays,
      unknownMacroDays,
      Object.hashAll(weeklyCaloriesPartial),
    );
  }
}
