/// Result of evaluating a fitness goal, biometric profile, or user query for physiological safety.
class GoalValidationResult {
  final bool isSafe;
  final String? issue;
  final String? recommendation;
  final double? safeRatePerWeek;
  final double? recommendedCalories;

  const GoalValidationResult({
    required this.isSafe,
    this.issue,
    this.recommendation,
    this.safeRatePerWeek,
    this.recommendedCalories,
  });

  factory GoalValidationResult.safe() =>
      const GoalValidationResult(isSafe: true);

  factory GoalValidationResult.unsafe({
    required String issue,
    required String recommendation,
    double? safeRatePerWeek,
    double? recommendedCalories,
  }) => GoalValidationResult(
    isSafe: false,
    issue: issue,
    recommendation: recommendation,
    safeRatePerWeek: safeRatePerWeek,
    recommendedCalories: recommendedCalories,
  );

  @override
  String toString() => isSafe
      ? 'GoalValidationResult(Safe)'
      : 'GoalValidationResult(Unsafe: $issue)';
}

/// Service dedicated to detecting unsafe fitness goals, extreme crash diets,
/// impossible muscle gain timelines, and invalid biometric measurements.
class GoalValidationService {
  static GoalValidationService? _instance;

  GoalValidationService();

  static GoalValidationService get instance =>
      _instance ??= GoalValidationService();

  static void resetInstance() {
    _instance = null;
  }

  // ===========================================================================
  // 1. QUERY & GOAL INTENT VALIDATION
  // ===========================================================================

  /// Analyzes a user message or query string to detect dangerous or physiologically impossible goals.
  GoalValidationResult validateGoalQuery(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return GoalValidationResult.safe();

    // 1. Extreme weight loss detection (e.g. "lose 30kg in 5 days", "lose 20kg in 2 weeks", "drop 10kg in 3 days")
    final extremeLossRegex = RegExp(
      r'(?:lose|drop|shed|burn|cut)\s*(\d+(?:\.\d+)?)\s*(?:kg|kilos|pounds|lbs)?\s*in\s*(\d+)\s*(?:days?|weeks?|months?|day|week|month)',
      caseSensitive: false,
    );

    final lossMatch = extremeLossRegex.firstMatch(lower);
    if (lossMatch != null) {
      final amount = double.tryParse(lossMatch.group(1) ?? '') ?? 0.0;
      final timeValue = int.tryParse(lossMatch.group(2) ?? '') ?? 1;
      final isDays = lower.contains('day');
      final isWeeks = lower.contains('week');
      final isMonths = lower.contains('month');

      double days = isDays
          ? timeValue.toDouble()
          : (isWeeks
                ? timeValue * 7.0
                : (isMonths ? timeValue * 30.0 : timeValue.toDouble()));
      if (days <= 0) days = 1;

      // Rate in kg per week (assume kg if unspecified, or convert lbs)
      final isLbs = lower.contains('lbs') || lower.contains('pounds');
      final kgAmount = isLbs ? amount * 0.453592 : amount;
      final weeklyRate = (kgAmount / days) * 7.0;

      // Safe fat loss is 0.5 to 1.0 kg/week. Above 1.5kg/week is clinically unsafe.
      if (weeklyRate > 1.5 || (kgAmount >= 10 && days <= 21)) {
        return GoalValidationResult.unsafe(
          issue:
              'Extreme and dangerous weight loss rate ($amount ${isLbs ? "lbs" : "kg"} in $timeValue ${isDays ? "days" : (isWeeks ? "weeks" : "months")}).',
          recommendation:
              'Rapid weight loss at this rate causes muscle wasting, metabolic shutdown, electrolyte imbalance, and gallstones. A safe, sustainable rate of fat loss is 0.5kg to 1.0kg (1-2 lbs) per week with a moderate caloric deficit of 300-500 kcal.',
          safeRatePerWeek: 0.75,
        );
      }
    }

    // Direct pattern checks for explicit extreme weight loss keywords
    if (lower.contains('lose 30kg in 5 days') ||
        lower.contains('lose 20kg in 2 weeks') ||
        lower.contains('lose 10kg in 3 days') ||
        lower.contains('lose 15kg in 1 week') ||
        lower.contains('lose 10kg in a week') ||
        lower.contains('starve myself to lose weight') ||
        lower.contains('water fast for 30 days')) {
      return GoalValidationResult.unsafe(
        issue: 'Severe crash dieting or dangerous weight loss rate.',
        recommendation:
            'Crash dieting severely degrades lean muscle and vital organs. Sustainable fat loss requires a moderate 300-500 kcal daily deficit, 1.6-2.2g/kg protein, and progressive resistance training for 0.5-1.0kg weekly progress.',
        safeRatePerWeek: 0.75,
      );
    }

    // 2. Extreme muscle gain detection (e.g. "gain 20kg muscle in one month", "gain 15kg muscle in 1 month")
    final extremeGainRegex = RegExp(
      r'(?:gain|build|pack on|add)\s*(\d+(?:\.\d+)?)\s*(?:kg|kilos|pounds|lbs)?\s*(?:of\s*)?(?:pure\s*)?muscle\s*in\s*(\d+)\s*(?:days?|weeks?|months?|day|week|month)',
      caseSensitive: false,
    );

    final gainMatch = extremeGainRegex.firstMatch(lower);
    if (gainMatch != null) {
      final amount = double.tryParse(gainMatch.group(1) ?? '') ?? 0.0;
      final timeValue = int.tryParse(gainMatch.group(2) ?? '') ?? 1;
      final isDays = lower.contains('day');
      final isWeeks = lower.contains('week');
      final isMonths = lower.contains('month');

      double days = isDays
          ? timeValue.toDouble()
          : (isWeeks
                ? timeValue * 7.0
                : (isMonths ? timeValue * 30.0 : timeValue.toDouble()));
      if (days <= 0) days = 30;

      final isLbs = lower.contains('lbs') || lower.contains('pounds');
      final kgAmount = isLbs ? amount * 0.453592 : amount;
      final monthlyRate = (kgAmount / days) * 30.0;

      // Natural muscle gain upper limit is ~1.0-1.5kg/month for beginners, and <0.5kg/month for intermediates
      if (monthlyRate > 2.0) {
        return GoalValidationResult.unsafe(
          issue:
              'Physiologically impossible muscle gain timeline ($amount ${isLbs ? "lbs" : "kg"} muscle in $timeValue ${isDays ? "days" : (isWeeks ? "weeks" : "months")}).',
          recommendation:
              'Building lean skeletal muscle requires progressive muscle protein synthesis. Natural athletes realistically build 0.5kg to 1.5kg of muscle per month with a slight 250-400 kcal surplus and progressive overload.',
          safeRatePerWeek: 0.25,
        );
      }
    }

    if (lower.contains('gain 20kg muscle in one month') ||
        lower.contains('gain 15kg muscle in 1 month') ||
        lower.contains('gain 10kg muscle in 2 weeks') ||
        lower.contains('gain 10kg muscle in 1 week')) {
      return GoalValidationResult.unsafe(
        issue: 'Unrealistic muscle gain expectations.',
        recommendation:
            'Gaining large amounts of pure muscle naturally takes consistent training over months. Aim for a progressive surplus of 250-400 kcal/day and 1.6-2.2g protein per kg bodyweight for steady 0.5-1.5kg monthly muscle growth.',
        safeRatePerWeek: 0.25,
      );
    }

    // 3. Dangerously low calorie detection (e.g. "eat 500 calories a day", "600 calorie diet", "300 calorie diet")
    final lowCalorieRegex = RegExp(
      r'\b(\d{2,3})\s*(?:calories|calorie|kcal|cals)\b',
      caseSensitive: false,
    );
    final calMatch = lowCalorieRegex.firstMatch(lower);
    if (calMatch != null) {
      final cals = double.tryParse(calMatch.group(1) ?? '') ?? 2000.0;
      if (cals < 1000) {
        return GoalValidationResult.unsafe(
          issue: 'Dangerously low daily caloric intake (${cals.toInt()} kcal).',
          recommendation:
              'Eating fewer than 1,000-1,200 calories per day can trigger severe nutrient deficiencies, muscle catabolism, and hormonal dysfunction. Maintain a moderate 300-500 kcal deficit below your maintenance calories.',
          recommendedCalories: 1500.0,
        );
      }
    }

    return GoalValidationResult.safe();
  }

  // ===========================================================================
  // 2. STRUCTURED BIOMETRIC & METRIC VALIDATION
  // ===========================================================================

  /// Validates biometric measurements for physiological plausibility.
  /// Rejects impossible entries like height: 20cm, weight: 500kg, age: 2 years.
  GoalValidationResult validateMetrics({
    required int age,
    required double heightCm,
    required double weightKg,
    double? targetWeightKg,
  }) {
    // 1. Age Validation (Safe range: 10 - 110 years)
    if (age < 10 || age > 110) {
      return GoalValidationResult.unsafe(
        issue: 'Invalid age: $age years.',
        recommendation:
            'Please verify your measurements. User age must be between 10 and 110 years for accurate training calibration.',
      );
    }

    // 2. Height Validation (Safe range: 90cm - 250cm)
    if (heightCm < 90 || heightCm > 250) {
      return GoalValidationResult.unsafe(
        issue: 'Invalid height: ${heightCm.toStringAsFixed(1)} cm.',
        recommendation:
            'Please verify your measurements. Height must be between 90 cm and 250 cm.',
      );
    }

    // 3. Weight Validation (Safe range: 25kg - 350kg)
    if (weightKg < 25 || weightKg > 350) {
      return GoalValidationResult.unsafe(
        issue: 'Invalid body weight: ${weightKg.toStringAsFixed(1)} kg.',
        recommendation:
            'Please verify your measurements. Body weight must be between 25 kg and 350 kg.',
      );
    }

    // 4. Target Weight & BMI plausibility
    if (targetWeightKg != null && targetWeightKg > 0) {
      if (targetWeightKg < 25 || targetWeightKg > 350) {
        return GoalValidationResult.unsafe(
          issue:
              'Invalid target weight: ${targetWeightKg.toStringAsFixed(1)} kg.',
          recommendation:
              'Please verify your measurements. Target weight must be between 25 kg and 350 kg.',
        );
      }

      final heightM = heightCm / 100.0;
      final targetBmi = targetWeightKg / (heightM * heightM);
      if (targetBmi < 15.0) {
        return GoalValidationResult.unsafe(
          issue:
              'Target weight results in severely underweight BMI (${targetBmi.toStringAsFixed(1)}).',
          recommendation:
              'Target BMI is below clinical safety thresholds (< 15.0). Please set a healthy target weight that maintains essential body mass.',
        );
      }
    }

    return GoalValidationResult.safe();
  }
}
