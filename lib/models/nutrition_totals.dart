import 'food_item.dart';
import 'meal_entry.dart';

/// Calories and macros consumed, summed over meal entries.
///
/// This is the one place consumed nutrition is added up. No meals means zero:
/// nothing is assumed about food that was not logged.
class NutritionTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// How many consumed items have unknown calories. They add 0 to
  /// [calories] as a placeholder only, so when this is more than 0 [calories]
  /// is a minimum, never an exact figure. The same holds for each macro.
  final int unknownCalorieItems;
  final int unknownProteinItems;
  final int unknownCarbItems;
  final int unknownFatItems;

  /// How many foods were added up.
  final int itemCount;

  const NutritionTotals({
    this.calories = 0.0,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fat = 0.0,
    this.unknownCalorieItems = 0,
    this.unknownProteinItems = 0,
    this.unknownCarbItems = 0,
    this.unknownFatItems = 0,
    this.itemCount = 0,
  });

  /// True when [calories] leaves out items whose calories are unknown.
  bool get caloriesAreLowerBound => unknownCalorieItems > 0;

  /// True when every food gave a value, so the total is exact. Only then may
  /// a rule say that intake is low or that an amount is still missing: an
  /// incomplete total can show a target was reached, never that it was not.
  bool get caloriesComplete => unknownCalorieItems == 0;
  bool get proteinComplete => unknownProteinItems == 0;
  bool get carbsComplete => unknownCarbItems == 0;
  bool get fatComplete => unknownFatItems == 0;

  /// True when at least one nutrient total leaves out unknown values.
  bool get hasUnknownValues =>
      !caloriesComplete || !proteinComplete || !carbsComplete || !fatComplete;

  /// What is left to reach [target], or null when the total is incomplete
  /// (the real remainder is then somewhere between 0 and the shown figure).
  double? caloriesRemaining(double target) =>
      caloriesComplete ? (target - calories).clamp(0.0, double.infinity) : null;

  double? proteinRemaining(double target) =>
      proteinComplete ? (target - protein).clamp(0.0, double.infinity) : null;

  /// A total as shown. Exact when every food gave a value; "14+" when some
  /// did not (the known ones are a valid minimum, since an amount cannot be
  /// negative); a dash when no food gave one, so nothing is known.
  String _label(double total, int unknown) {
    if (unknown == 0) return '${total.round()}';
    if (unknown >= itemCount) return '\u2014';
    return '${total.round()}+';
  }

  /// The calories as shown: "190", "190+" when a minimum, "\u2014" when
  /// nothing is known.
  String get caloriesLabel => _label(calories, unknownCalorieItems);

  String get proteinLabel => _label(protein, unknownProteinItems);
  String get carbsLabel => _label(carbs, unknownCarbItems);
  String get fatLabel => _label(fat, unknownFatItems);

  String _grams(String label) => label == '\u2014' ? label : '${label}g';

  /// The macros with their unit: "14g", "14+g" or "\u2014".
  String get proteinText => _grams(proteinLabel);
  String get carbsText => _grams(carbsLabel);
  String get fatText => _grams(fatLabel);

  static const NutritionTotals empty = NutritionTotals();

  factory NutritionTotals.fromMeals(Iterable<MealEntry> meals) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var unknownCalorieItems = 0;
    var unknownProteinItems = 0;
    var unknownCarbItems = 0;
    var unknownFatItems = 0;
    var itemCount = 0;
    for (final meal in meals) {
      itemCount += meal.consumedFoods.length;
      unknownCalorieItems += meal.unknownCalorieCount;
      unknownProteinItems += meal.unknownCount(FoodItem.proteinKey);
      unknownCarbItems += meal.unknownCount(FoodItem.carbohydrateKey);
      unknownFatItems += meal.unknownCount(FoodItem.fatKey);
      calories += meal.totalCalories;
      protein += meal.totalProtein;
      carbs += meal.totalCarbohydrates;
      fat += meal.totalFats;
    }
    return NutritionTotals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      unknownCalorieItems: unknownCalorieItems,
      unknownProteinItems: unknownProteinItems,
      unknownCarbItems: unknownCarbItems,
      unknownFatItems: unknownFatItems,
      itemCount: itemCount,
    );
  }

  NutritionTotals operator +(NutritionTotals other) => NutritionTotals(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
    unknownCalorieItems: unknownCalorieItems + other.unknownCalorieItems,
    unknownProteinItems: unknownProteinItems + other.unknownProteinItems,
    unknownCarbItems: unknownCarbItems + other.unknownCarbItems,
    unknownFatItems: unknownFatItems + other.unknownFatItems,
    itemCount: itemCount + other.itemCount,
  );
}
