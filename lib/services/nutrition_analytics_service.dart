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

    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFats = 0.0;
    int proteinGoalHits = 0;
    int calorieGoalHits = 0;

    for (final log in history) {
      final cals = log.dailyCalories;
      final protein = log.dailyProtein;
      final carbs = log.dailyCarbohydrates;
      final fats = log.dailyFats;

      totalCalories += cals;
      totalProtein += protein;
      totalCarbs += carbs;
      totalFats += fats;

      if (log.proteinGoal > 0 && protein >= log.proteinGoal) {
        proteinGoalHits++;
      }

      if (log.calorieGoal > 0) {
        final minTarget = log.calorieGoal * 0.85;
        final maxTarget = log.calorieGoal * 1.15;
        if (cals >= minTarget && cals <= maxTarget) {
          calorieGoalHits++;
        }
      }
    }

    final count = history.length;
    final avgDailyCals = count > 0 ? totalCalories / count : 0.0;
    final avgProtein = count > 0 ? totalProtein / count : 0.0;
    final avgCarbs = count > 0 ? totalCarbs / count : 0.0;
    final avgFats = count > 0 ? totalFats / count : 0.0;

    final proteinHitPct = count > 0 ? (proteinGoalHits / count) * 100.0 : 0.0;
    final calConsistencyPct = count > 0 ? (calorieGoalHits / count) * 100.0 : 0.0;

    final streak = _calculateNutritionStreak(history);
    final weeklyCals = _calculateWeeklyCalories(history);
    final macroDist = _calculateMacroBalance(avgProtein, avgCarbs, avgFats);

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

  /// Returns 7-day calorie totals array ending today
  List<double> _calculateWeeklyCalories(List<NutritionLog> history) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekly = List<double>.filled(7, 0.0);

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
      }
    }

    return weekly;
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
