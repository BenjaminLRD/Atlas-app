import 'recommended_workout.dart';

/// Structured daily workout recommendation for the AI Coach proactive brief.
class WorkoutRecommendation {
  final String id;
  final String workoutTitle;
  final String
  splitType; // 'push', 'pull', 'legs', 'upper', 'lower', 'full_body', 'rest'
  final List<String> focusMuscles;
  final int estimatedDurationMinutes;
  final double estimatedCalories;
  final int exerciseCount;
  final bool isRestDay;
  final String intensityLevel; // 'High', 'Moderate', 'Deload', 'Rest'
  final String reasoning;
  final List<String> recommendedExercises;

  const WorkoutRecommendation({
    required this.id,
    required this.workoutTitle,
    required this.splitType,
    this.focusMuscles = const [],
    this.estimatedDurationMinutes = 45,
    this.estimatedCalories = 320.0,
    this.exerciseCount = 4,
    this.isRestDay = false,
    this.intensityLevel = 'Moderate',
    this.reasoning = 'Aligned with your weekly periodization schedule.',
    this.recommendedExercises = const [],
  });

  /// Convenience getters
  String get title => workoutTitle;
  String get split => splitType;

  factory WorkoutRecommendation.fromRecommendedWorkout(
    RecommendedWorkout workout, {
    String? reasoning,
    String? intensityLevel,
  }) {
    final lowerTitle = workout.title.toLowerCase();
    String split = 'full_body';
    if (lowerTitle.contains('push')) {
      split = 'push';
    } else if (lowerTitle.contains('pull')) {
      split = 'pull';
    } else if (lowerTitle.contains('leg')) {
      split = 'legs';
    } else if (lowerTitle.contains('upper')) {
      split = 'upper';
    } else if (lowerTitle.contains('lower')) {
      split = 'lower';
    }

    final isRest =
        workout.intensity.toLowerCase() == 'recovery' ||
        workout.title.toLowerCase().contains('rest');

    return WorkoutRecommendation(
      id: workout.id,
      workoutTitle: workout.title,
      splitType: split,
      focusMuscles: workout.focusMuscleGroups,
      estimatedDurationMinutes: workout.estimatedDuration,
      estimatedCalories: workout.estimatedDuration * 7.5,
      exerciseCount: workout.exercises.length,
      isRestDay: isRest,
      intensityLevel: intensityLevel ?? (isRest ? 'Rest' : workout.intensity),
      reasoning: reasoning ?? workout.reason,
      recommendedExercises: workout.exercises,
    );
  }

  factory WorkoutRecommendation.restDay({
    String reasoning =
        'Scheduled recovery day to optimize muscle protein synthesis and nervous system replenishment.',
  }) {
    return WorkoutRecommendation(
      id: 'rec_rest_${DateTime.now().millisecondsSinceEpoch}',
      workoutTitle: 'Active Recovery & Mobility',
      splitType: 'rest',
      focusMuscles: const ['Full Body Mobility', 'Stretching'],
      estimatedDurationMinutes: 20,
      estimatedCalories: 100.0,
      exerciseCount: 3,
      isRestDay: true,
      intensityLevel: 'Rest',
      reasoning: reasoning,
      recommendedExercises: const [
        'Hip Openers',
        'Thoracic Spine Rotations',
        'Hamstring Flow',
      ],
    );
  }

  factory WorkoutRecommendation.fromJson(Map<String, dynamic> json) {
    return WorkoutRecommendation(
      id: json['id'] as String? ?? '',
      workoutTitle:
          json['workoutTitle'] as String? ??
          json['workout_title'] as String? ??
          'Daily Workout',
      splitType:
          json['splitType'] as String? ??
          json['split_type'] as String? ??
          'full_body',
      focusMuscles:
          (json['focusMuscles'] as List? ??
                  json['focus_muscles'] as List? ??
                  [])
              .map((e) => e.toString())
              .toList(),
      estimatedDurationMinutes:
          (json['estimatedDurationMinutes'] as num? ??
                  json['estimated_duration_minutes'] as num? ??
                  45)
              .toInt(),
      estimatedCalories:
          (json['estimatedCalories'] as num? ??
                  json['estimated_calories'] as num? ??
                  320.0)
              .toDouble(),
      exerciseCount:
          (json['exerciseCount'] as num? ?? json['exercise_count'] as num? ?? 4)
              .toInt(),
      isRestDay:
          json['isRestDay'] as bool? ?? json['is_rest_day'] as bool? ?? false,
      intensityLevel:
          json['intensityLevel'] as String? ??
          json['intensity_level'] as String? ??
          'Moderate',
      reasoning: json['reasoning'] as String? ?? '',
      recommendedExercises:
          (json['recommendedExercises'] as List? ??
                  json['recommended_exercises'] as List? ??
                  [])
              .map((e) => e.toString())
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workout_title': workoutTitle,
    'split_type': splitType,
    'focus_muscles': focusMuscles,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'estimated_calories': estimatedCalories,
    'exercise_count': exerciseCount,
    'is_rest_day': isRestDay,
    'intensity_level': intensityLevel,
    'reasoning': reasoning,
    'recommended_exercises': recommendedExercises,
  };

  WorkoutRecommendation copyWith({
    String? id,
    String? workoutTitle,
    String? splitType,
    List<String>? focusMuscles,
    int? estimatedDurationMinutes,
    double? estimatedCalories,
    int? exerciseCount,
    bool? isRestDay,
    String? intensityLevel,
    String? reasoning,
    List<String>? recommendedExercises,
  }) {
    return WorkoutRecommendation(
      id: id ?? this.id,
      workoutTitle: workoutTitle ?? this.workoutTitle,
      splitType: splitType ?? this.splitType,
      focusMuscles: focusMuscles ?? this.focusMuscles,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      exerciseCount: exerciseCount ?? this.exerciseCount,
      isRestDay: isRestDay ?? this.isRestDay,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      reasoning: reasoning ?? this.reasoning,
      recommendedExercises: recommendedExercises ?? this.recommendedExercises,
    );
  }
}
