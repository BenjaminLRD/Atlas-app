import 'recommended_workout.dart';

/// Domain model representing a multi-session adaptive workout plan tailored to user goals and readiness.
class AdaptiveWorkoutPlan {
  final String id;
  final String goalType; // 'build_muscle', 'lose_weight', 'increase_strength', 'stay_fit'
  final String fitnessLevel; // 'beginner', 'intermediate', 'advanced'
  final List<String> weeklySchedule; // Days e.g. ['Mon', 'Wed', 'Fri']
  final List<RecommendedWorkout> sessions;
  final DateTime generatedAt;
  final DateTime lastModified;

  const AdaptiveWorkoutPlan({
    required this.id,
    this.goalType = 'build_muscle',
    this.fitnessLevel = 'intermediate',
    this.weeklySchedule = const ['Monday', 'Wednesday', 'Friday', 'Saturday'],
    this.sessions = const [],
    required this.generatedAt,
    required this.lastModified,
  });

  factory AdaptiveWorkoutPlan.fromJson(Map<String, dynamic> json) {
    return AdaptiveWorkoutPlan(
      id: json['id'] as String? ?? '',
      goalType: json['goalType'] as String? ??
          (json['goal_type'] as String? ?? 'build_muscle'),
      fitnessLevel: json['fitnessLevel'] as String? ??
          (json['fitness_level'] as String? ?? 'intermediate'),
      weeklySchedule: (json['weeklySchedule'] as List<dynamic>? ??
              (json['weekly_schedule'] as List<dynamic>? ?? []))
          .map((e) => e.toString())
          .toList(),
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .map((s) => RecommendedWorkout.fromJson(s as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : (json['generated_at'] != null
              ? DateTime.parse(json['generated_at'] as String)
              : DateTime.now()),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : (json['last_modified'] != null
              ? DateTime.parse(json['last_modified'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'goal_type': goalType,
        'fitness_level': fitnessLevel,
        'weekly_schedule': weeklySchedule,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'generated_at': generatedAt.toIso8601String(),
        'last_modified': lastModified.toIso8601String(),
      };

  AdaptiveWorkoutPlan copyWith({
    String? id,
    String? goalType,
    String? fitnessLevel,
    List<String>? weeklySchedule,
    List<RecommendedWorkout>? sessions,
    DateTime? generatedAt,
    DateTime? lastModified,
  }) {
    return AdaptiveWorkoutPlan(
      id: id ?? this.id,
      goalType: goalType ?? this.goalType,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      sessions: sessions ?? this.sessions,
      generatedAt: generatedAt ?? this.generatedAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptiveWorkoutPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          goalType == other.goalType &&
          fitnessLevel == other.fitnessLevel;

  @override
  int get hashCode => id.hashCode ^ goalType.hashCode ^ fitnessLevel.hashCode;
}
