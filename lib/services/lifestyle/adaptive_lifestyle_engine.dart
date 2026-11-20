/// Recommended autonomous adjustments to training and nutrition.
class LifestyleAdaptationRecommendation {
  final bool isVolumeAdjusted;
  final double volumeAdjustmentPercentage; // e.g. -30.0%
  final bool isCaloriesAdjusted;
  final double calorieDeltaKcal; // e.g. +250 kcal
  final bool isDeloadPrescribed;
  final String adaptationReasoning;
  final DateTime generatedAt;

  const LifestyleAdaptationRecommendation({
    required this.isVolumeAdjusted,
    required this.volumeAdjustmentPercentage,
    required this.isCaloriesAdjusted,
    required this.calorieDeltaKcal,
    required this.isDeloadPrescribed,
    required this.adaptationReasoning,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'volume_adjusted': isVolumeAdjusted,
    'volume_delta_pct': volumeAdjustmentPercentage,
    'calories_adjusted': isCaloriesAdjusted,
    'calorie_delta_kcal': calorieDeltaKcal,
    'deload_prescribed': isDeloadPrescribed,
    'reasoning': adaptationReasoning,
    'generated_at': generatedAt.toIso8601String(),
  };
}

/// Autonomous Lifestyle Adaptation Engine.
/// Dynamically modulates training volume, intensity, rest days, and nutritional targets
/// in response to real-world sleep debt, acute stress, and physiological readiness.
class AdaptiveLifestyleEngine {
  static AdaptiveLifestyleEngine? _instance;
  static AdaptiveLifestyleEngine get instance =>
      _instance ??= AdaptiveLifestyleEngine();

  static void resetInstance() {
    _instance = null;
  }

  /// Calculates lifestyle adjustments based on recovery score and sleep duration.
  LifestyleAdaptationRecommendation evaluateLifestyleContext({
    required double recoveryScore, // 0-100
    required double sleepDurationHours, // e.g. 5.5h
    bool isHighStressDay = false,
  }) {
    final now = DateTime.now();

    // 1. Critical Fatigue / Sleep Debt (<6h sleep or <55 recovery)
    if (sleepDurationHours < 6.0 || recoveryScore < 55.0) {
      return LifestyleAdaptationRecommendation(
        isVolumeAdjusted: true,
        volumeAdjustmentPercentage: -30.0,
        isCaloriesAdjusted: true,
        calorieDeltaKcal: 200.0, // Increase calories slightly to support immune/recovery function
        isDeloadPrescribed: recoveryScore < 45.0,
        adaptationReasoning:
            'Sleep restricted to ${sleepDurationHours}h with recovery score ${recoveryScore.round()}/100. '
            'Auto-regulating volume by -30% to prevent connective tissue strain.',
        generatedAt: now,
      );
    }

    // 2. High Stress Day
    if (isHighStressDay) {
      return LifestyleAdaptationRecommendation(
        isVolumeAdjusted: true,
        volumeAdjustmentPercentage: -15.0,
        isCaloriesAdjusted: false,
        calorieDeltaKcal: 0.0,
        isDeloadPrescribed: false,
        adaptationReasoning: 'Elevated lifestyle stress detected. Moderating volume by -15%.',
        generatedAt: now,
      );
    }

    // 3. Optimal State
    return LifestyleAdaptationRecommendation(
      isVolumeAdjusted: false,
      volumeAdjustmentPercentage: 0.0,
      isCaloriesAdjusted: false,
      calorieDeltaKcal: 0.0,
      isDeloadPrescribed: false,
      adaptationReasoning: 'Optimal physiological readiness (${recoveryScore.round()}/100). Maintain scheduled overload.',
      generatedAt: now,
    );
  }
}
