import '../../models/daily_nutrition.dart';

/// Calorie and protein figures for a run of days, without counting unknown
/// values as zero.
///
/// A day whose foods all gave a value for a nutrient is "complete" for it.
/// Averages and hit rates use only complete days, so a food with no protein
/// value cannot drag a rate down (or up). Days that were left out are counted,
/// so a summary can say so.
class WeeklyNutritionStats {
  /// Days with at least one food logged.
  final int days;

  /// Days whose calories / protein are complete.
  final int calorieDays;
  final int proteinDays;

  /// Complete protein days that reached the protein target.
  final int proteinHitDays;

  /// Average calories over complete calorie days, or null when there are none.
  final double? averageCalories;

  /// Share of complete protein days that reached the target (0 to 100), or
  /// null when there are none.
  final double? proteinHitPercent;

  const WeeklyNutritionStats({
    required this.days,
    required this.calorieDays,
    required this.proteinDays,
    required this.proteinHitDays,
    required this.averageCalories,
    required this.proteinHitPercent,
  });

  /// Days left out of the calorie average because some food had no calories.
  int get calorieDaysExcluded => days - calorieDays;

  /// Days left out of the protein rate because some food had no protein.
  int get proteinDaysExcluded => days - proteinDays;

  bool get hasExcludedDays =>
      calorieDaysExcluded > 0 || proteinDaysExcluded > 0;

  /// [proteinHitRatio] is the share of the protein target that counts as a
  /// hit (the weekly reviews use 0.85).
  factory WeeklyNutritionStats.from(
    Iterable<DailyNutrition> history, {
    double proteinHitRatio = 0.85,
  }) {
    var days = 0;
    var calorieDays = 0;
    var proteinDays = 0;
    var proteinHitDays = 0;
    var calories = 0.0;
    for (final day in history) {
      days++;
      final totals = day.totalsConsumed;
      if (totals.caloriesComplete) {
        calorieDays++;
        calories += totals.calories;
      }
      if (totals.proteinComplete) {
        proteinDays++;
        if (totals.protein >= day.targets.protein * proteinHitRatio) {
          proteinHitDays++;
        }
      }
    }
    return WeeklyNutritionStats(
      days: days,
      calorieDays: calorieDays,
      proteinDays: proteinDays,
      proteinHitDays: proteinHitDays,
      averageCalories: calorieDays > 0 ? calories / calorieDays : null,
      proteinHitPercent: proteinDays > 0
          ? proteinHitDays / proteinDays * 100.0
          : null,
    );
  }

  /// "3 of 7 days left out: foods without calorie or protein values." or null
  /// when nothing was left out.
  String? get excludedNote {
    if (!hasExcludedDays) return null;
    final parts = <String>[];
    if (calorieDaysExcluded > 0) {
      parts.add(
        '$calorieDaysExcluded ${calorieDaysExcluded == 1 ? 'day' : 'days'} '
        'without complete calories',
      );
    }
    if (proteinDaysExcluded > 0) {
      parts.add(
        '$proteinDaysExcluded ${proteinDaysExcluded == 1 ? 'day' : 'days'} '
        'without complete protein',
      );
    }
    return 'Left out of the figures: ${parts.join(', ')}.';
  }
}
