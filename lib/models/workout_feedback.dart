/// Domain model capturing post-workout user difficulty rating and subjective feedback.
class WorkoutFeedback {
  final String id;
  final String workoutId;
  final String difficultyRating; // 'too_easy', 'perfect', 'too_hard'
  final double completionQuality; // 0.0 to 1.0 (percentage completed)
  final double volumeAchieved; // kg total volume
  final double targetVolume; // kg target volume
  final String notes;
  final DateTime createdAt;

  const WorkoutFeedback({
    required this.id,
    required this.workoutId,
    this.difficultyRating = 'perfect',
    this.completionQuality = 1.0,
    this.volumeAchieved = 0.0,
    this.targetVolume = 0.0,
    this.notes = '',
    required this.createdAt,
  });

  factory WorkoutFeedback.fromJson(Map<String, dynamic> json) {
    return WorkoutFeedback(
      id: json['id'] as String? ?? '',
      workoutId: json['workoutId'] as String? ??
          (json['workout_id'] as String? ?? ''),
      difficultyRating: json['difficultyRating'] as String? ??
          (json['difficulty_rating'] as String? ?? 'perfect'),
      completionQuality: (json['completionQuality'] as num? ??
              (json['completion_quality'] as num? ?? 1.0))
          .toDouble(),
      volumeAchieved: (json['volumeAchieved'] as num? ??
              (json['volume_achieved'] as num? ?? 0.0))
          .toDouble(),
      targetVolume: (json['targetVolume'] as num? ??
              (json['target_volume'] as num? ?? 0.0))
          .toDouble(),
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workout_id': workoutId,
        'difficulty_rating': difficultyRating,
        'completion_quality': completionQuality,
        'volume_achieved': volumeAchieved,
        'target_volume': targetVolume,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  WorkoutFeedback copyWith({
    String? id,
    String? workoutId,
    String? difficultyRating,
    double? completionQuality,
    double? volumeAchieved,
    double? targetVolume,
    String? notes,
    DateTime? createdAt,
  }) {
    return WorkoutFeedback(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      completionQuality: completionQuality ?? this.completionQuality,
      volumeAchieved: volumeAchieved ?? this.volumeAchieved,
      targetVolume: targetVolume ?? this.targetVolume,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutFeedback &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workoutId == other.workoutId &&
          difficultyRating == other.difficultyRating;

  @override
  int get hashCode => id.hashCode ^ workoutId.hashCode ^ difficultyRating.hashCode;
}
