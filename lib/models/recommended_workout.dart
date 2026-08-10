/// Domain model representing a single recommended workout session.
class RecommendedWorkout {
  final String id;
  final String title;
  final List<String> focusMuscleGroups;
  final String intensity; // 'heavy', 'moderate', 'light', 'recovery'
  final List<String> exercises;
  final String reason;
  final int estimatedDuration; // minutes

  const RecommendedWorkout({
    required this.id,
    required this.title,
    this.focusMuscleGroups = const [],
    this.intensity = 'moderate',
    this.exercises = const [],
    required this.reason,
    this.estimatedDuration = 45,
  });

  factory RecommendedWorkout.fromJson(Map<String, dynamic> json) {
    return RecommendedWorkout(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      focusMuscleGroups: (json['focusMuscleGroups'] as List<dynamic>? ??
              (json['focus_muscle_groups'] as List<dynamic>? ?? []))
          .map((e) => e.toString())
          .toList(),
      intensity: json['intensity'] as String? ?? 'moderate',
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      reason: json['reason'] as String? ?? '',
      estimatedDuration: json['estimatedDuration'] as int? ??
          (json['estimated_duration'] as int? ?? 45),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'focus_muscle_groups': focusMuscleGroups,
        'intensity': intensity,
        'exercises': exercises,
        'reason': reason,
        'estimated_duration': estimatedDuration,
      };

  RecommendedWorkout copyWith({
    String? id,
    String? title,
    List<String>? focusMuscleGroups,
    String? intensity,
    List<String>? exercises,
    String? reason,
    int? estimatedDuration,
  }) {
    return RecommendedWorkout(
      id: id ?? this.id,
      title: title ?? this.title,
      focusMuscleGroups: focusMuscleGroups ?? this.focusMuscleGroups,
      intensity: intensity ?? this.intensity,
      exercises: exercises ?? this.exercises,
      reason: reason ?? this.reason,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendedWorkout &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          intensity == other.intensity;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ intensity.hashCode;
}
