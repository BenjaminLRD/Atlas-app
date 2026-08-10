/// Domain model representing adaptive training intelligence (fatigue, readiness, load, intensity recommendations).
class TrainingState {
  final String id;
  final int fatigueScore; // 0 - 100
  final int readinessScore; // 0 - 100
  final double trainingLoad; // 7-day cumulative load
  final double weeklyVolume; // 7-day total volume lifted in kg
  final String recommendedIntensity; // 'heavy_training', 'moderate_training', 'recovery', 'rest'
  final String recommendation; // Reasoning narrative
  final DateTime lastUpdated;

  const TrainingState({
    required this.id,
    this.fatigueScore = 30,
    this.readinessScore = 80,
    this.trainingLoad = 120.0,
    this.weeklyVolume = 15000.0,
    this.recommendedIntensity = 'moderate_training',
    required this.recommendation,
    required this.lastUpdated,
  });

  factory TrainingState.fromJson(Map<String, dynamic> json) {
    return TrainingState(
      id: json['id'] as String? ?? '',
      fatigueScore: json['fatigueScore'] as int? ??
          (json['fatigue_score'] as int? ?? 30),
      readinessScore: json['readinessScore'] as int? ??
          (json['readiness_score'] as int? ?? 80),
      trainingLoad: (json['trainingLoad'] as num? ??
              (json['training_load'] as num? ?? 120.0))
          .toDouble(),
      weeklyVolume: (json['weeklyVolume'] as num? ??
              (json['weekly_volume'] as num? ?? 15000.0))
          .toDouble(),
      recommendedIntensity: json['recommendedIntensity'] as String? ??
          (json['recommended_intensity'] as String? ?? 'moderate_training'),
      recommendation: json['recommendation'] as String? ?? '',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : (json['last_updated'] != null
              ? DateTime.parse(json['last_updated'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fatigue_score': fatigueScore,
        'readiness_score': readinessScore,
        'training_load': trainingLoad,
        'weekly_volume': weeklyVolume,
        'recommended_intensity': recommendedIntensity,
        'recommendation': recommendation,
        'last_updated': lastUpdated.toIso8601String(),
      };

  TrainingState copyWith({
    String? id,
    int? fatigueScore,
    int? readinessScore,
    double? trainingLoad,
    double? weeklyVolume,
    String? recommendedIntensity,
    String? recommendation,
    DateTime? lastUpdated,
  }) {
    return TrainingState(
      id: id ?? this.id,
      fatigueScore: fatigueScore ?? this.fatigueScore,
      readinessScore: readinessScore ?? this.readinessScore,
      trainingLoad: trainingLoad ?? this.trainingLoad,
      weeklyVolume: weeklyVolume ?? this.weeklyVolume,
      recommendedIntensity: recommendedIntensity ?? this.recommendedIntensity,
      recommendation: recommendation ?? this.recommendation,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          readinessScore == other.readinessScore &&
          recommendedIntensity == other.recommendedIntensity;

  @override
  int get hashCode =>
      id.hashCode ^ readinessScore.hashCode ^ recommendedIntensity.hashCode;
}
