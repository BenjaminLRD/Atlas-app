import '../models/nutrition_log.dart';
import '../models/nutrition_summary.dart';

/// Pure analytics engine for computing aggregate nutrition metrics
class NutritionAnalyticsService {
  const NutritionAnalyticsService();

  /// Calculates a NutritionSummary from historical NutritionLogs.
  NutritionSummary calculateSummary(List<NutritionLog> history) {
    if (history.isEmpty) {
      return NutritionSummary.empty();
    }

    // Unknown values are never added as zero. The total is a minimum when
    // any day misses a value. Each average and rate uses only the days that
    // are complete for that nutrient (see NutritionSummary), so a food with
    // no protein value cannot lower the protein average or hit rate. The
    // macro split uses only days where protein, carbs and fat are complete.
    double totalCalories = 0.0;
    var calorieDays = 0, proteinDays = 0, carbDays = 0, fatDays = 0;
    var macroDays = 0;
    double calorieSum = 0.0, proteinSum = 0.0, carbSum = 0.0, fatSum = 0.0;
    double macroProtein = 0.0, macroCarbs = 0.0, macroFats = 0.0;
    int proteinGoalHits = 0;
    int calorieGoalHits = 0;
    int unknownCalorieDays = 0, unknownProteinDays = 0, unknownMacroDays = 0;

    for (final log in history) {
      final t = log.totals;
      totalCalories += t.calories;

      if (t.caloriesComplete) {
        calorieDays++;
        calorieSum += t.calories;
        if (log.calorieGoal > 0) {
          final minTarget = log.calorieGoal * 0.85;
          final maxTarget = log.calorieGoal * 1.15;
          if (t.calories >= minTarget && t.calories <= maxTarget) {
            calorieGoalHits++;
          }
        }
      } else {
        unknownCalorieDays++;
      }

      if (t.proteinComplete) {
        proteinDays++;
        proteinSum += t.protein;
        if (log.proteinGoal > 0 && t.protein >= log.proteinGoal) {
          proteinGoalHits++;
        }
      } else {
        unknownProteinDays++;
      }

      if (t.carbsComplete) {
        carbDays++;
        carbSum += t.carbs;
      }
      if (t.fatComplete) {
        fatDays++;
        fatSum += t.fat;
      }

      if (t.proteinComplete && t.carbsComplete && t.fatComplete) {
        macroDays++;
        macroProtein += t.protein;
        macroCarbs += t.carbs;
        macroFats += t.fat;
      } else {
        unknownMacroDays++;
      }
    }

    final count = history.length;
    final avgDailyCals = calorieDays > 0 ? calorieSum / calorieDays : 0.0;
    final avgProtein = proteinDays > 0 ? proteinSum / proteinDays : 0.0;
    final avgCarbs = carbDays > 0 ? carbSum / carbDays : 0.0;
    final avgFats = fatDays > 0 ? fatSum / fatDays : 0.0;

    final proteinHitPct = proteinDays > 0
        ? (proteinGoalHits / proteinDays) * 100.0
        : 0.0;
    final calConsistencyPct = calorieDays > 0
        ? (calorieGoalHits / calorieDays) * 100.0
        : 0.0;

    final streak = _calculateNutritionStreak(history);
    final (weeklyCals, weeklyPartial) = _calculateWeeklyCalories(history);
    final macroDist = macroDays > 0
        ? _calculateMacroBalance(
            macroProtein / macroDays,
            macroCarbs / macroDays,
            macroFats / macroDays,
          )
        : const {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0};

    return NutritionSummary(
      totalCaloriesConsumed: totalCalories,
      averageDailyCalories: avgDailyCals,
      averageProtein: avgProtein,
      averageCarbohydrates: avgCarbs,
      averageFats: avgFats,
      proteinGoalHitPercentage: proteinHitPct,
      calorieGoalConsistency: calConsistencyPct,
      currentNutritionStreak: streak,
      weeklyCalories: weeklyCals,
      macroBalance: macroDist,
      daysCounted: count,
      unknownCalorieDays: unknownCalorieDays,
      unknownProteinDays: unknownProteinDays,
      unknownMacroDays: unknownMacroDays,
      weeklyCaloriesPartial: weeklyPartial,
    );
  }

  /// Calculates current streak of consecutive logged active days
  int _calculateNutritionStreak(List<NutritionLog> history) {
    if (history.isEmpty) return 0;

    // Sort by date descending (most recent first)
    final sorted = List<NutritionLog>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    for (final log in sorted) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      final diff = checkDate.difference(logDate).inDays;

      if (diff == 0 || diff == 1) {
        if (log.dailyCalories > 0 || log.completedMeals > 0) {
          streak++;
          checkDate = logDate;
        } else if (diff == 0) {
          // Today not logged yet, continue check from yesterday
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return streak;
  }

  /// Returns 7-day calorie totals array ending today, and for each day
  /// whether it leaves out foods with unknown calories (a minimum then).
  (List<double>, List<bool>) _calculateWeeklyCalories(
    List<NutritionLog> history,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekly = List<double>.filled(7, 0.0);
    final partial = List<bool>.filled(7, false);

    for (int i = 0; i < 7; i++) {
      final targetDate = today.subtract(Duration(days: 6 - i));
      final matchingLog = history.cast<NutritionLog?>().firstWhere(
        (log) =>
            log != null &&
            log.date.year == targetDate.year &&
            log.date.month == targetDate.month &&
            log.date.day == targetDate.day,
        orElse: () => null,
      );

      if (matchingLog != null) {
        weekly[i] = matchingLog.dailyCalories;
        partial[i] = !matchingLog.totals.caloriesComplete;
      }
    }

    return (weekly, partial);
  }

  /// Calculates percentage of calories derived from protein, carbs, and fats
  Map<String, double> _calculateMacroBalance(
    double proteinGrams,
    double carbsGrams,
    double fatsGrams,
  ) {
    final proteinCals = proteinGrams * 4.0;
    final carbsCals = carbsGrams * 4.0;
    final fatsCals = fatsGrams * 9.0;
    final totalCals = proteinCals + carbsCals + fatsCals;

    if (totalCals <= 0) {
      return const {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0};
    }

    return {
      'protein': (proteinCals / totalCals) * 100.0,
      'carbs': (carbsCals / totalCals) * 100.0,
      'fats': (fatsCals / totalCals) * 100.0,
    };
  }
}
