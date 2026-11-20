import '../../models/nutrition_totals.dart';

/// The calorie line of the weight-goal banner.
///
/// With every logged food's calories known it says how much is left. Foods
/// with unknown calories make the logged total a minimum: that can show the
/// target is reached, but never how much is left, so the banner then says what
/// is known and what is missing instead of a remaining figure.
String weightGoalCalorieStatus({
  required double targetCalories,
  required NutritionTotals totals,
  required bool isSurplusGoal,
}) {
  final kind = isSurplusGoal ? 'surplus' : 'target';
  final reached =
      'Daily ${isSurplusGoal ? 'surplus' : 'calorie'} target reached!';

  if (totals.caloriesComplete) {
    final remaining = (targetCalories - totals.calories).clamp(0.0, 9999.0);
    return remaining > 0
        ? '${remaining.toStringAsFixed(0)} kcal remaining for today\'s $kind'
        : reached;
  }
  // A minimum at or above the target proves the target was reached.
  if (totals.calories >= targetCalories) return reached;
  if (totals.unknownCalorieItems >= totals.itemCount) {
    return 'Calories are unknown for the foods you logged, so the amount '
        'remaining cannot be calculated.';
  }
  return 'At least ${totals.calories.toStringAsFixed(0)} kcal logged; some '
      'foods have no calorie value, so the amount remaining is unknown.';
}
