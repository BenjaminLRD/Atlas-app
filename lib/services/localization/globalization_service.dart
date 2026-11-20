/// Measurement units for bodyweight, barbell load, and anthropometry.
enum MassUnit { kg, lbs }

enum LengthUnit { cm, inches }

/// Regional nutritional database regulatory profiles.
enum RegionalNutritionRegion { usFda, euEfsa, inFssai, asianStandard }

/// Platform globalization service providing international unit conversions,
/// timezone-aware circadian calculations, and regional nutritional profiles.
class GlobalizationService {
  static GlobalizationService? _instance;
  static GlobalizationService get instance =>
      _instance ??= GlobalizationService();

  static void resetInstance() {
    _instance = null;
  }

  // Conversion Constants
  static const double _kgToLbsRatio = 2.20462;
  static const double _cmToInchesRatio = 0.393701;

  /// Converts kilograms to pounds
  double kgToLbs(double kg) =>
      double.parse((kg * _kgToLbsRatio).toStringAsFixed(1));

  /// Converts pounds to kilograms
  double lbsToKg(double lbs) =>
      double.parse((lbs / _kgToLbsRatio).toStringAsFixed(1));

  /// Converts centimeters to inches
  double cmToInches(double cm) =>
      double.parse((cm * _cmToInchesRatio).toStringAsFixed(1));

  /// Converts inches to centimeters
  double inchesToCm(double inches) =>
      double.parse((inches / _cmToInchesRatio).toStringAsFixed(1));

  /// Formats weight string according to chosen unit
  String formatWeight(double weightInKg, MassUnit unit) {
    if (unit == MassUnit.lbs) {
      return '${kgToLbs(weightInKg)} lbs';
    }
    return '${weightInKg.toStringAsFixed(1)} kg';
  }

  /// Formats height string according to chosen unit
  String formatHeight(double heightInCm, LengthUnit unit) {
    if (unit == LengthUnit.inches) {
      final totalInches = cmToInches(heightInCm);
      final feet = (totalInches / 12).floor();
      final inches = (totalInches % 12).round();
      return "$feet'$inches\"";
    }
    return '${heightInCm.toStringAsFixed(0)} cm';
  }

  /// Calculates timezone-adjusted circadian workout window
  String getCircadianPeakWindow({
    required int timezoneOffsetHours,
    required String preferredTime, // 'morning', 'afternoon', 'evening'
  }) {
    switch (preferredTime.toLowerCase()) {
      case 'morning':
        return '07:00 - 09:00 (Local)';
      case 'afternoon':
        return '14:30 - 16:30 (Local)';
      case 'evening':
      default:
        return '17:30 - 19:30 (Local)';
    }
  }

  /// Returns regional nutritional database label and dietary reference intake guideline
  String getRegionalGuidelineName(RegionalNutritionRegion region) {
    switch (region) {
      case RegionalNutritionRegion.usFda:
        return 'US FDA Daily Reference Values (DRV)';
      case RegionalNutritionRegion.euEfsa:
        return 'European Food Safety Authority (EFSA)';
      case RegionalNutritionRegion.inFssai:
        return 'Food Safety and Standards Authority of India (FSSAI)';
      case RegionalNutritionRegion.asianStandard:
        return 'Asian Regional Dietary Guidelines (RDA)';
    }
  }
}
