/// Dynamic, learning-based training preference profile synthesized from
/// workout history, performance telemetry, skipped sessions, and post-workout feedback.
class TrainingPreferenceProfile {
  final List<String> preferredExercises;
  final List<String> avoidedExercises;
  final List<String> favoriteMuscleGroups;
  final int preferredWorkoutDurationMinutes;
  final String
  preferredTrainingStyle; // 'Dumbbells', 'Barbell', 'Bodyweight', 'Hypertrophy', 'Strength'
  final String averageIntensity; // 'Moderate', 'High', 'RPE 8'
  final String preferredRepRanges; // '6-8', '8-12', '12-15'
  final String
  equipmentPreference; // 'Dumbbells', 'Barbell', 'Cables & Machines', 'Bodyweight'
  final Map<String, int>
  exerciseCompletionStats; // Exercise Name -> Completed Count
  final Map<String, int> exerciseSkipStats; // Exercise Name -> Skipped Count
  final Map<String, int>
  workoutSplitCompletionStats; // Split (Push, Pull, Legs, etc.) -> Completed Count
  final Map<String, int> workoutSplitSkipStats; // Split -> Skipped Count
  final Map<String, double>
  progressiveOverloadNotes; // Exercise Name -> Recommended Next Weight (kg)
  final List<String> difficultyRatings; // 'Too Easy', 'Perfect', 'Too Hard'

  const TrainingPreferenceProfile({
    this.preferredExercises = const [],
    this.avoidedExercises = const [],
    this.favoriteMuscleGroups = const [],
    this.preferredWorkoutDurationMinutes = 45,
    this.preferredTrainingStyle = 'Hypertrophy',
    this.averageIntensity = 'Moderate',
    this.preferredRepRanges = '8-12',
    this.equipmentPreference = 'Dumbbells & Barbells',
    this.exerciseCompletionStats = const {},
    this.exerciseSkipStats = const {},
    this.workoutSplitCompletionStats = const {},
    this.workoutSplitSkipStats = const {},
    this.progressiveOverloadNotes = const {},
    this.difficultyRatings = const [],
  });

  /// Factory creating default initial training preference profile.
  factory TrainingPreferenceProfile.initial() {
    return const TrainingPreferenceProfile(
      preferredExercises: [],
      avoidedExercises: [],
      favoriteMuscleGroups: ['Chest', 'Back', 'Legs'],
      preferredWorkoutDurationMinutes: 45,
      preferredTrainingStyle: 'Hypertrophy',
      averageIntensity: 'Moderate',
      preferredRepRanges: '8-12',
      equipmentPreference: 'All Equipment',
      exerciseCompletionStats: {},
      exerciseSkipStats: {},
      workoutSplitCompletionStats: {},
      workoutSplitSkipStats: {},
      progressiveOverloadNotes: {},
      difficultyRatings: [],
    );
  }

  /// Calculates total workouts logged
  int get totalCompletedWorkouts =>
      workoutSplitCompletionStats.values.fold(0, (sum, count) => sum + count);

  /// Calculates total workouts skipped
  int get totalSkippedWorkouts =>
      workoutSplitSkipStats.values.fold(0, (sum, count) => sum + count);

  /// Completion rate ratio (0.0 to 1.0)
  double get overallCompletionRate {
    final total = totalCompletedWorkouts + totalSkippedWorkouts;
    if (total == 0) return 1.0;
    return totalCompletedWorkouts / total;
  }

  /// Checks if a specific exercise is avoided/disliked
  bool isExerciseAvoided(String exerciseName) {
    final clean = exerciseName.trim().toLowerCase();
    return avoidedExercises.any((a) => a.trim().toLowerCase() == clean);
  }

  /// Checks if a specific exercise is preferred
  bool isExercisePreferred(String exerciseName) {
    final clean = exerciseName.trim().toLowerCase();
    return preferredExercises.any((p) => p.trim().toLowerCase() == clean);
  }

  TrainingPreferenceProfile copyWith({
    List<String>? preferredExercises,
    List<String>? avoidedExercises,
    List<String>? favoriteMuscleGroups,
    int? preferredWorkoutDurationMinutes,
    String? preferredTrainingStyle,
    String? averageIntensity,
    String? preferredRepRanges,
    String? equipmentPreference,
    Map<String, int>? exerciseCompletionStats,
    Map<String, int>? exerciseSkipStats,
    Map<String, int>? workoutSplitCompletionStats,
    Map<String, int>? workoutSplitSkipStats,
    Map<String, double>? progressiveOverloadNotes,
    List<String>? difficultyRatings,
  }) {
    return TrainingPreferenceProfile(
      preferredExercises: preferredExercises ?? this.preferredExercises,
      avoidedExercises: avoidedExercises ?? this.avoidedExercises,
      favoriteMuscleGroups: favoriteMuscleGroups ?? this.favoriteMuscleGroups,
      preferredWorkoutDurationMinutes:
          preferredWorkoutDurationMinutes ??
          this.preferredWorkoutDurationMinutes,
      preferredTrainingStyle:
          preferredTrainingStyle ?? this.preferredTrainingStyle,
      averageIntensity: averageIntensity ?? this.averageIntensity,
      preferredRepRanges: preferredRepRanges ?? this.preferredRepRanges,
      equipmentPreference: equipmentPreference ?? this.equipmentPreference,
      exerciseCompletionStats:
          exerciseCompletionStats ?? this.exerciseCompletionStats,
      exerciseSkipStats: exerciseSkipStats ?? this.exerciseSkipStats,
      workoutSplitCompletionStats:
          workoutSplitCompletionStats ?? this.workoutSplitCompletionStats,
      workoutSplitSkipStats:
          workoutSplitSkipStats ?? this.workoutSplitSkipStats,
      progressiveOverloadNotes:
          progressiveOverloadNotes ?? this.progressiveOverloadNotes,
      difficultyRatings: difficultyRatings ?? this.difficultyRatings,
    );
  }

  Map<String, dynamic> toJson() => {
    'preferredExercises': preferredExercises,
    'avoidedExercises': avoidedExercises,
    'favoriteMuscleGroups': favoriteMuscleGroups,
    'preferredWorkoutDurationMinutes': preferredWorkoutDurationMinutes,
    'preferredTrainingStyle': preferredTrainingStyle,
    'averageIntensity': averageIntensity,
    'preferredRepRanges': preferredRepRanges,
    'equipmentPreference': equipmentPreference,
    'exerciseCompletionStats': exerciseCompletionStats,
    'exerciseSkipStats': exerciseSkipStats,
    'workoutSplitCompletionStats': workoutSplitCompletionStats,
    'workoutSplitSkipStats': workoutSplitSkipStats,
    'progressiveOverloadNotes': progressiveOverloadNotes,
    'difficultyRatings': difficultyRatings,
  };

  factory TrainingPreferenceProfile.fromJson(Map<String, dynamic> json) {
    return TrainingPreferenceProfile(
      preferredExercises:
          (json['preferredExercises'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avoidedExercises:
          (json['avoidedExercises'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      favoriteMuscleGroups:
          (json['favoriteMuscleGroups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      preferredWorkoutDurationMinutes:
          (json['preferredWorkoutDurationMinutes'] as num?)?.toInt() ?? 45,
      preferredTrainingStyle:
          json['preferredTrainingStyle'] as String? ?? 'Hypertrophy',
      averageIntensity: json['averageIntensity'] as String? ?? 'Moderate',
      preferredRepRanges: json['preferredRepRanges'] as String? ?? '8-12',
      equipmentPreference:
          json['equipmentPreference'] as String? ?? 'All Equipment',
      exerciseCompletionStats:
          (json['exerciseCompletionStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      exerciseSkipStats:
          (json['exerciseSkipStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      workoutSplitCompletionStats:
          (json['workoutSplitCompletionStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      workoutSplitSkipStats:
          (json['workoutSplitSkipStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      progressiveOverloadNotes:
          (json['progressiveOverloadNotes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
      difficultyRatings:
          (json['difficultyRatings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
