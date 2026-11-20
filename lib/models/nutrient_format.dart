import 'nutrient_status.dart';

/// The one way a nutrient amount is written for the user.
///
/// - unknown: a dash, whatever number happens to be stored
/// - known zero: "0.0g", a real zero
/// - known: its value and unit
/// - estimate: the value with a tilde, never as exact
class NutrientFormat {
  NutrientFormat._();

  /// Shown instead of a value that is not known.
  static const String missing = '\u2014';

  /// [value] in grams (or [unit]) with [digits] decimals, for [status].
  static String grams(
    double? value,
    NutrientStatus status, {
    int digits = 1,
    String unit = 'g',
  }) {
    if (value == null || status == NutrientStatus.unknown) return missing;
    final text = '${value.toStringAsFixed(digits)}$unit';
    return status == NutrientStatus.estimate ? '~$text' : text;
  }

  /// Calories: "196 kcal", "~287 kcal", or "\u2014 kcal" when unknown.
  static String kcal(double? value, NutrientStatus status) {
    if (value == null || status == NutrientStatus.unknown) {
      return '$missing kcal';
    }
    final text = '${value.toStringAsFixed(0)} kcal';
    return status == NutrientStatus.estimate ? '~$text' : text;
  }
}
