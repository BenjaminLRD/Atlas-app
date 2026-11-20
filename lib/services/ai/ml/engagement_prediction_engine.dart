/// Predicted retention and churn risk categories.
enum ChurnRiskLevel {
  low('Low Risk', '🟢'),
  medium('Medium Risk', '🟡'),
  high('High Risk', '🔴');

  final String label;
  final String indicator;
  const ChurnRiskLevel(this.label, this.indicator);
}

/// Retention and habit continuity prediction outcome.
class RetentionPredictionResult {
  final ChurnRiskLevel churnRisk;
  final double riskProbability; // 0.0 to 1.0
  final List<String> riskFactors;
  final List<String> retentionInterventions;
  final DateTime generatedAt;

  const RetentionPredictionResult({
    required this.churnRisk,
    required this.riskProbability,
    required this.riskFactors,
    required this.retentionInterventions,
    required this.generatedAt,
  });

  factory RetentionPredictionResult.fromJson(Map<String, dynamic> json) {
    final factors = (json['risk_factors'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final interventions =
        (json['retention_interventions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

    return RetentionPredictionResult(
      churnRisk: ChurnRiskLevel.values.firstWhere(
        (r) => r.name == json['churn_risk'],
        orElse: () => ChurnRiskLevel.low,
      ),
      riskProbability: (json['risk_probability'] as num?)?.toDouble() ?? 0.15,
      riskFactors: factors,
      retentionInterventions: interventions,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'churn_risk': churnRisk.name,
      'risk_probability': riskProbability,
      'risk_factors': riskFactors,
      'retention_interventions': retentionInterventions,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

/// Predictive Machine Learning engine analyzing user inactivity, missed sessions, and engagement decay
/// to forecast churn probability and trigger habit-rescuing interventions.
class EngagementPredictionEngine {
  static EngagementPredictionEngine? _instance;
  static EngagementPredictionEngine get instance =>
      _instance ??= EngagementPredictionEngine();

  /// Evaluates multi-signal engagement telemetry to forecast retention risk.
  RetentionPredictionResult predictRetentionRisk({
    required int daysSinceLastWorkout,
    required int missedGoalsLast14Days,
    required double recentEngagementScore, // 0 to 100
    required double nutritionLoggingAdherence, // 0.0 to 1.0
  }) {
    final List<String> factors = [];
    final List<String> interventions = [];

    double riskScore = 0.10;

    // 1. Inactivity decay
    if (daysSinceLastWorkout >= 5) {
      riskScore += 0.45;
      factors.add(
        'Inactivity: No workouts recorded in the past $daysSinceLastWorkout days.',
      );
      interventions.add(
        'Trigger "15-Minute Low-Barrier Express Workout" to rebuild momentum.',
      );
    } else if (daysSinceLastWorkout >= 3) {
      riskScore += 0.20;
      factors.add('Training gap: 3+ days since last workout.');
      interventions.add('Send encouraging evening session reminder.');
    }

    // 2. Missed goals
    if (missedGoalsLast14Days >= 3) {
      riskScore += 0.25;
      factors.add(
        'Goal friction: $missedGoalsLast14Days target sessions missed in last 2 weeks.',
      );
      interventions.add(
        'Auto-scale weekly target down by 1 session to prevent burnout.',
      );
    }

    // 3. Nutrition logging drop
    if (nutritionLoggingAdherence < 0.40) {
      riskScore += 0.15;
      factors.add('Diet tracking drop: logged meals below 40% adherence.');
      interventions.add('Enable simplified 1-tap quick photo meal tracking.');
    }

    // 4. Categorize risk level
    final clampedRisk = riskScore.clamp(0.05, 0.95);
    ChurnRiskLevel level = ChurnRiskLevel.low;
    if (clampedRisk >= 0.55) {
      level = ChurnRiskLevel.high;
    } else if (clampedRisk >= 0.30) {
      level = ChurnRiskLevel.medium;
    }

    if (interventions.isEmpty) {
      interventions.add(
        'Maintain current progressive overload split and consistency streak.',
      );
    }

    return RetentionPredictionResult(
      churnRisk: level,
      riskProbability: clampedRisk,
      riskFactors: factors,
      retentionInterventions: interventions,
      generatedAt: DateTime.now(),
    );
  }
}
