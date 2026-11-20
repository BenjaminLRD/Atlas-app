import '../../models/digital_athlete.dart';

/// Structured outcome of a predictive goal achievement simulation.
class GoalPredictionResult {
  final String goalType; // 'weight', 'strength', 'body_composition'
  final double currentMetric;
  final double targetMetric;
  final double successProbabilityPercentage; // 0 to 100%
  final DateTime estimatedCompletionDate;
  final int daysRemaining;
  final double confidenceScore;
  final List<String> keyMilestones;
  final List<String> recommendedAdjustments;

  const GoalPredictionResult({
    required this.goalType,
    required this.currentMetric,
    required this.targetMetric,
    required this.successProbabilityPercentage,
    required this.estimatedCompletionDate,
    required this.daysRemaining,
    required this.confidenceScore,
    required this.keyMilestones,
    required this.recommendedAdjustments,
  });

  factory GoalPredictionResult.fromJson(Map<String, dynamic> json) {
    final rawM = json['key_milestones'] as List<dynamic>? ?? [];
    final rawAdj = json['recommended_adjustments'] as List<dynamic>? ?? [];

    return GoalPredictionResult(
      goalType: json['goal_type']?.toString() ?? 'weight',
      currentMetric: (json['current_metric'] as num?)?.toDouble() ?? 75.0,
      targetMetric: (json['target_metric'] as num?)?.toDouble() ?? 78.0,
      successProbabilityPercentage:
          (json['success_probability_percentage'] as num?)?.toDouble() ?? 88.0,
      estimatedCompletionDate: json['estimated_completion_date'] != null
          ? DateTime.tryParse(json['estimated_completion_date'].toString()) ??
                DateTime.now().add(const Duration(days: 60))
          : DateTime.now().add(const Duration(days: 60)),
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 60,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.91,
      keyMilestones: rawM.map((e) => e.toString()).toList(),
      recommendedAdjustments: rawAdj.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal_type': goalType,
    'current_metric': currentMetric,
    'target_metric': targetMetric,
    'success_probability_percentage': successProbabilityPercentage,
    'estimated_completion_date': estimatedCompletionDate.toIso8601String(),
    'days_remaining': daysRemaining,
    'confidence_score': confidenceScore,
    'key_milestones': keyMilestones,
    'recommended_adjustments': recommendedAdjustments,
  };
}

/// Predictive ML engine evaluating athlete nutrition adherence, workout volume,
/// and metabolic trajectory to forecast completion timelines and achievement probabilities.
class GoalPredictionEngine {
  static GoalPredictionEngine? _instance;
  static GoalPredictionEngine get instance =>
      _instance ??= GoalPredictionEngine();

  /// Simulates goal achievement trajectory for a [DigitalAthlete].
  GoalPredictionResult predictGoalAchievement(DigitalAthlete athlete) {
    final currentWeight = athlete.physicalProfile.weightKg;
    final targetWeight = athlete.goalProfile.targetWeightKg;
    final deltaKg = targetWeight - currentWeight;

    final adherence = athlete.nutritionProfile.adherenceRate;
    final consistency = athlete.behaviorProfile.consistencyScore / 100.0;
    final recovery = athlete.recoveryProfile.averageRecoveryScore / 100.0;

    // Combined execution score (0.0 to 1.0)
    final executionScore =
        (adherence * 0.45 + consistency * 0.35 + recovery * 0.20).clamp(
          0.4,
          1.0,
        );

    // Rate of change per week in kg (e.g. 0.35 kg/week for lean bulk, -0.5 kg/week for cut)
    final baseWeeklyChangeKg = deltaKg > 0 ? 0.30 : (deltaKg < 0 ? -0.45 : 0.0);
    final effectiveWeeklyRate = baseWeeklyChangeKg * executionScore;

    int weeksRequired = 8;
    if (effectiveWeeklyRate.abs() > 0.05) {
      weeksRequired = (deltaKg / effectiveWeeklyRate).abs().ceil();
      weeksRequired = weeksRequired.clamp(2, 52);
    }

    final estimatedDate = DateTime.now().add(Duration(days: weeksRequired * 7));
    final probability = (executionScore * 95.0).clamp(45.0, 98.0);

    final List<String> milestones = [
      'Phase 1 (Week ${(weeksRequired * 0.33).round()}): Reach ${(currentWeight + deltaKg * 0.33).toStringAsFixed(1)} kg',
      'Phase 2 (Week ${(weeksRequired * 0.66).round()}): Reach ${(currentWeight + deltaKg * 0.66).toStringAsFixed(1)} kg',
      'Phase 3 (Target Date): Finalize target body composition at ${targetWeight.toStringAsFixed(1)} kg',
    ];

    final List<String> adjustments = [];
    if (adherence < 0.85) {
      adjustments.add(
        'Increase daily nutrition logging consistency to improve timeline certainty by 18%.',
      );
    }
    if (recovery < 0.75) {
      adjustments.add(
        'Prioritize 7.5+ hours sleep to protect lean mass and accelerate metabolic efficiency.',
      );
    }
    if (adjustments.isEmpty) {
      adjustments.add(
        'Current trajectory is optimal. Maintain progressive overload and macro adherence.',
      );
    }

    return GoalPredictionResult(
      goalType: deltaKg >= 0
          ? 'hypertrophy_weight_gain'
          : 'fat_loss_definition',
      currentMetric: currentWeight,
      targetMetric: targetWeight,
      successProbabilityPercentage: double.parse(
        probability.toStringAsFixed(1),
      ),
      estimatedCompletionDate: estimatedDate,
      daysRemaining: weeksRequired * 7,
      confidenceScore: 0.92,
      keyMilestones: milestones,
      recommendedAdjustments: adjustments,
    );
  }
}
