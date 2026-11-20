/// Types of user feedback and behavioral memory events tracked by the AI Coach.
enum MemoryEventType {
  exerciseLiked('EXERCISE_LIKED'),
  exerciseDisliked('EXERCISE_DISLIKED'),
  exerciseReplaced('EXERCISE_REPLACED'),
  exerciseEnjoyed('EXERCISE_ENJOYED'),
  exerciseSkipped('EXERCISE_SKIPPED'),
  foodLiked('FOOD_LIKED'),
  foodDisliked('FOOD_DISLIKED'),
  recommendationHelpful('RECOMMENDATION_HELPFUL'),
  recommendationUnhelpful('RECOMMENDATION_UNHELPFUL'),
  preferenceUpdated('PREFERENCE_UPDATED'),
  workoutCompleted('WORKOUT_COMPLETED'),
  workoutSkipped('WORKOUT_SKIPPED'),
  workoutDifficultyFeedback('WORKOUT_DIFFICULTY_FEEDBACK'),
  prAchieved('PR_ACHIEVED');

  final String code;
  const MemoryEventType(this.code);

  static MemoryEventType fromCode(String code) {
    return MemoryEventType.values.firstWhere(
      (e) => e.code.toUpperCase() == code.toUpperCase(),
      orElse: () => MemoryEventType.preferenceUpdated,
    );
  }
}

/// Represents an individual memory event recording athlete feedback or interaction.
class MemoryEvent {
  final String id;
  final MemoryEventType type;
  final String target;
  final String? secondaryTarget;
  final int scoreDelta;
  final String? notes;
  final DateTime timestamp;

  const MemoryEvent({
    required this.id,
    required this.type,
    required this.target,
    this.secondaryTarget,
    this.scoreDelta = 0,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'target': target,
    'secondaryTarget': secondaryTarget,
    'scoreDelta': scoreDelta,
    'notes': notes,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MemoryEvent.fromJson(Map<String, dynamic> json) {
    return MemoryEvent(
      id:
          json['id'] as String? ??
          'evt_${DateTime.now().millisecondsSinceEpoch}',
      type: MemoryEventType.fromCode(
        json['type'] as String? ?? 'PREFERENCE_UPDATED',
      ),
      target: json['target'] as String? ?? '',
      secondaryTarget: json['secondaryTarget'] as String?,
      scoreDelta: (json['scoreDelta'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
