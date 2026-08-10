/// Enum representing athlete fatigue level classification
enum FatigueLevel {
  low,
  moderate,
  high,
  critical,
}

/// Enum representing actionable recovery recommendations
enum RecoveryRecommendation {
  trainNormal,
  reduceIntensity,
  activeRecovery,
  deloadWeek,
  restDay,
}

/// Domain model representing detailed athlete recovery intelligence, fatigue levels, and deload status.
class RecoveryState {
  final String id;
  final int recoveryScore; // 0 to 100
  final FatigueLevel fatigueLevel;
  final double trainingStress;
  final double sleepQuality; // 0.0 to 1.0
  final String recoveryTrend; // 'improving', 'stable', 'declining'
  final RecoveryRecommendation recommendation;
  final bool isDeloadRecommended;
  final DateTime lastUpdated;

  const RecoveryState({
    required this.id,
    this.recoveryScore = 80,
    this.fatigueLevel = FatigueLevel.low,
    this.trainingStress = 35.0,
    this.sleepQuality = 0.85,
    this.recoveryTrend = 'stable',
    this.recommendation = RecoveryRecommendation.trainNormal,
    this.isDeloadRecommended = false,
    required this.lastUpdated,
  });

  factory RecoveryState.fromJson(Map<String, dynamic> json) {
    return RecoveryState(
      id: json['id'] as String? ?? '',
      recoveryScore: json['recoveryScore'] as int? ??
          (json['recovery_score'] as int? ?? 80),
      fatigueLevel: FatigueLevel.values.firstWhere(
        (e) =>
            e.name ==
            (json['fatigueLevel'] as String? ??
                (json['fatigue_level'] as String? ?? 'low')),
        orElse: () => FatigueLevel.low,
      ),
      trainingStress: (json['trainingStress'] as num? ??
              (json['training_stress'] as num? ?? 35.0))
          .toDouble(),
      sleepQuality: (json['sleepQuality'] as num? ??
              (json['sleep_quality'] as num? ?? 0.85))
          .toDouble(),
      recoveryTrend: json['recoveryTrend'] as String? ??
          (json['recovery_trend'] as String? ?? 'stable'),
      recommendation: RecoveryRecommendation.values.firstWhere(
        (e) =>
            e.name ==
            (json['recommendation'] as String? ?? 'trainNormal'),
        orElse: () => RecoveryRecommendation.trainNormal,
      ),
      isDeloadRecommended: json['isDeloadRecommended'] as bool? ??
          (json['is_deload_recommended'] as bool? ?? false),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : (json['last_updated'] != null
              ? DateTime.parse(json['last_updated'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recovery_score': recoveryScore,
        'fatigue_level': fatigueLevel.name,
        'training_stress': trainingStress,
        'sleep_quality': sleepQuality,
        'recovery_trend': recoveryTrend,
        'recommendation': recommendation.name,
        'is_deload_recommended': isDeloadRecommended,
        'last_updated': lastUpdated.toIso8601String(),
      };

  RecoveryState copyWith({
    String? id,
    int? recoveryScore,
    FatigueLevel? fatigueLevel,
    double? trainingStress,
    double? sleepQuality,
    String? recoveryTrend,
    RecoveryRecommendation? recommendation,
    bool? isDeloadRecommended,
    DateTime? lastUpdated,
  }) {
    return RecoveryState(
      id: id ?? this.id,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      fatigueLevel: fatigueLevel ?? this.fatigueLevel,
      trainingStress: trainingStress ?? this.trainingStress,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      recoveryTrend: recoveryTrend ?? this.recoveryTrend,
      recommendation: recommendation ?? this.recommendation,
      isDeloadRecommended: isDeloadRecommended ?? this.isDeloadRecommended,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          recoveryScore == other.recoveryScore &&
          fatigueLevel == other.fatigueLevel &&
          isDeloadRecommended == other.isDeloadRecommended;

  @override
  int get hashCode =>
      id.hashCode ^ recoveryScore.hashCode ^ fatigueLevel.hashCode ^ isDeloadRecommended.hashCode;
}
