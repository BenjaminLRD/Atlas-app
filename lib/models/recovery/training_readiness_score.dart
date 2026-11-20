import 'readiness_inputs.dart';

/// Quantifies athlete training readiness on a 0 - 100 scale using weighted physiological signals.
///
/// A score exists only when a physiological signal (sleep, HRV or heart rate)
/// was recorded ([isAvailable]). Factors without data are null and left out:
/// the score is built from the factors that are known, with their weights
/// rescaled. With no physiological data the result is "unavailable" and
/// [score] must not be read as a measurement.
class TrainingReadinessScore {
  /// 0.0 - 100.0 when [isAvailable]; 0.0 and meaningless otherwise.
  final double score;

  /// 'Ready to Train', 'Moderate Readiness', 'Recovery Recommended' or 'Unavailable'.
  final String status;

  /// 'PR Ready', 'Optimal', 'Caution', 'Deload' or 'Unavailable'.
  final String readinessGrade;

  /// Which real inputs this result was built from.
  final ReadinessInputs inputs;

  // 5 weighted factor sub-scores (0 - 100 each). Null = no data for the factor.
  final double? workoutRecoveryContribution; // 30% weight
  final double? sleepContribution; // 25% weight
  final double? hrvContribution; // 20% weight
  final double? trainingLoadContribution; // 15% weight
  final double? nutritionContribution; // 10% weight

  final List<String> riskFactors;
  final String explanation;
  final DateTime calculatedAt;

  const TrainingReadinessScore({
    required this.score,
    required this.status,
    required this.readinessGrade,
    this.inputs = ReadinessInputs.empty,
    this.workoutRecoveryContribution,
    this.sleepContribution,
    this.hrvContribution,
    this.trainingLoadContribution,
    this.nutritionContribution,
    this.riskFactors = const [],
    required this.explanation,
    required this.calculatedAt,
  });

  /// True when the score is built from at least one physiological signal.
  bool get isAvailable => inputs.hasPhysiological;

  /// Status classification helpers (all false when unavailable).
  bool get isHighReadiness => isAvailable && score >= 70.0;
  bool get isModerateReadiness => isAvailable && score >= 50.0 && score < 70.0;
  bool get isLowReadiness => isAvailable && score < 50.0;

  /// Optimal workout volume adjustment (-50% to 0%). Unavailable readiness
  /// changes nothing (1.0).
  double get suggestedVolumeMultiplier {
    if (!isAvailable) return 1.0;
    if (score >= 85.0) return 1.0; // Full volume & progressive overload
    if (score >= 70.0) return 1.0; // Normal volume
    if (score >= 50.0) return 0.8; // Maintain intensity, reduce volume by 20%
    return 0.5; // Recovery mode, reduce volume by 50%
  }

  /// A result for the case where there is not enough real data.
  factory TrainingReadinessScore.unavailable({
    ReadinessInputs inputs = ReadinessInputs.empty,
    List<String> riskFactors = const [],
    DateTime? timestamp,
    double? workoutRecovery,
    double? trainingLoadScore,
    double? nutritionScore,
  }) {
    return TrainingReadinessScore(
      score: 0.0,
      status: 'Unavailable',
      readinessGrade: 'Unavailable',
      inputs: inputs,
      workoutRecoveryContribution: workoutRecovery,
      trainingLoadContribution: trainingLoadScore,
      nutritionContribution: nutritionScore,
      riskFactors: riskFactors,
      explanation:
          inputs.unavailableReason ??
          'Not enough recorded data to judge readiness.',
      calculatedAt: timestamp ?? DateTime.now(),
    );
  }

  /// Weighted readiness from the factors that are known. Returns an
  /// unavailable result when [inputs] has no physiological signal.
  factory TrainingReadinessScore.calculate({
    required ReadinessInputs inputs,
    double? workoutRecovery,
    double? sleepScore,
    double? hrvScore,
    double? trainingLoadScore,
    double? nutritionScore,
    List<String> riskFactors = const [],
    DateTime? timestamp,
  }) {
    if (!inputs.hasPhysiological) {
      return TrainingReadinessScore.unavailable(
        inputs: inputs,
        riskFactors: riskFactors,
        timestamp: timestamp,
        workoutRecovery: workoutRecovery,
        trainingLoadScore: trainingLoadScore,
        nutritionScore: nutritionScore,
      );
    }

    // Five weighted factors; a missing factor drops out and the rest are rescaled.
    var weighted = 0.0;
    var weights = 0.0;
    void add(double? value, double weight) {
      if (value == null) return;
      weighted += value * weight;
      weights += weight;
    }

    add(workoutRecovery, 0.30);
    add(sleepScore, 0.25);
    add(hrvScore, 0.20);
    add(trainingLoadScore, 0.15);
    add(nutritionScore, 0.10);

    final finalScore = (weights == 0 ? 0.0 : weighted / weights).clamp(
      0.0,
      100.0,
    );

    final String status;
    final String grade;
    String explanation;

    if (finalScore >= 90.0) {
      status = 'Ready to Train';
      grade = 'PR Ready';
      explanation =
          'Optimal physiological recovery. Prime nervous system readiness for high intensity and progressive overload.';
    } else if (finalScore >= 70.0) {
      status = 'Ready to Train';
      grade = 'Optimal';
      explanation =
          'Good overall readiness. Normal training volume and planned workout execution recommended.';
    } else if (finalScore >= 50.0) {
      status = 'Moderate Readiness';
      grade = 'Caution';
      explanation =
          'Moderate fatigue detected. Maintain movement intensity but reduce volume sets by ~20%.';
    } else {
      status = 'Recovery Recommended';
      grade = 'Deload';
      explanation =
          'High systemic fatigue or insufficient recovery. Active recovery, mobility, or light cardio recommended.';
    }

    final missing = inputs.missingPhysiological;
    if (missing.isNotEmpty) {
      explanation =
          '$explanation Not recorded: ${ReadinessInputs.joinNames(missing)}.';
    }

    return TrainingReadinessScore(
      score: double.parse(finalScore.toStringAsFixed(1)),
      status: status,
      readinessGrade: grade,
      inputs: inputs,
      workoutRecoveryContribution: workoutRecovery,
      sleepContribution: sleepScore,
      hrvContribution: hrvScore,
      trainingLoadContribution: trainingLoadScore,
      nutritionContribution: nutritionScore,
      riskFactors: riskFactors,
      explanation: explanation,
      calculatedAt: timestamp ?? DateTime.now(),
    );
  }

  /// Saved results without recorded inputs (older versions computed them with
  /// default values) read as unavailable, never as measured.
  factory TrainingReadinessScore.fromJson(Map<String, dynamic> json) {
    final inputs = ReadinessInputs.fromJson(
      json['inputs'] as Map<String, dynamic>?,
    );
    double? d(String k) => (json[k] as num?)?.toDouble();
    final risks =
        (json['riskFactors'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    final at = json['calculatedAt'] != null
        ? DateTime.tryParse(json['calculatedAt'] as String)
        : null;
    if (!inputs.hasPhysiological) {
      return TrainingReadinessScore.unavailable(
        inputs: inputs,
        riskFactors: risks,
        timestamp: at,
      );
    }
    return TrainingReadinessScore(
      score: (json['score'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'Unavailable',
      readinessGrade: json['readinessGrade'] as String? ?? 'Unavailable',
      inputs: inputs,
      workoutRecoveryContribution: d('workoutRecoveryContribution'),
      sleepContribution: d('sleepContribution'),
      hrvContribution: d('hrvContribution'),
      trainingLoadContribution: d('trainingLoadContribution'),
      nutritionContribution: d('nutritionContribution'),
      riskFactors: risks,
      explanation: json['explanation'] as String? ?? '',
      calculatedAt: at ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    'status': status,
    'readinessGrade': readinessGrade,
    'inputs': inputs.toJson(),
    if (workoutRecoveryContribution != null)
      'workoutRecoveryContribution': workoutRecoveryContribution,
    if (sleepContribution != null) 'sleepContribution': sleepContribution,
    if (hrvContribution != null) 'hrvContribution': hrvContribution,
    if (trainingLoadContribution != null)
      'trainingLoadContribution': trainingLoadContribution,
    if (nutritionContribution != null)
      'nutritionContribution': nutritionContribution,
    'riskFactors': riskFactors,
    'explanation': explanation,
    'calculatedAt': calculatedAt.toIso8601String(),
  };
}
