import 'workout_history.dart';

/// Type alias for API convenience and flexible naming
typedef WorkoutSet = WorkoutSessionSet;

/// Structured representation of a single completed set in an active workout.
class WorkoutSessionSet {
  final int setNumber;
  final double weight;
  final int reps;
  final bool completed;
  final double? rpe;
  final double? previousWeight;
  final int? previousReps;
  final bool isPR;
  final DateTime? completedAt;

  /// How long the set took, in seconds. Null for sets recorded before set
  /// timing existed and for sets that were never timed.
  final int? durationSeconds;

  const WorkoutSessionSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.completed = false,
    this.rpe,
    this.previousWeight,
    this.previousReps,
    this.isPR = false,
    this.completedAt,
    this.durationSeconds,
  });

  /// Total volume lifted in this set (weight × reps) if completed
  double get volume => completed ? (weight * reps) : 0.0;

  factory WorkoutSessionSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionSet(
      setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      rpe: (json['rpe'] as num?)?.toDouble(),
      previousWeight: (json['previousWeight'] as num?)?.toDouble(),
      previousReps: (json['previousReps'] as num?)?.toInt(),
      isPR: json['isPR'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'completed': completed,
    if (rpe != null) 'rpe': rpe,
    if (previousWeight != null) 'previousWeight': previousWeight,
    if (previousReps != null) 'previousReps': previousReps,
    'isPR': isPR,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };

  WorkoutSessionSet copyWith({
    int? setNumber,
    double? weight,
    int? reps,
    bool? completed,
    double? rpe,
    double? previousWeight,
    int? previousReps,
    bool? isPR,
    DateTime? completedAt,
    int? durationSeconds,
  }) {
    return WorkoutSessionSet(
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      rpe: rpe ?? this.rpe,
      previousWeight: previousWeight ?? this.previousWeight,
      previousReps: previousReps ?? this.previousReps,
      isPR: isPR ?? this.isPR,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

/// Structured representation of an exercise performed within a workout session.
class WorkoutSessionExercise {
  final String id;
  final String name;
  final String muscleGroup;
  final List<WorkoutSessionSet> sets;
  final String? notes;
  final bool isCompleted;

  const WorkoutSessionExercise({
    required this.id,
    required this.name,
    this.muscleGroup = 'Full Body',
    this.sets = const [],
    this.notes,
    this.isCompleted = false,
  });

  /// Compatibility aliases
  String get exerciseId => id;
  String get exerciseName => name;
  bool get completed => isCompleted;

  /// Alias for muscleGroup for API compatibility
  String get primaryTarget => muscleGroup;

  /// Total volume lifted across completed sets for this exercise
  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);

  /// Peak weight used across completed sets
  double get maxWeight => sets
      .where((s) => s.completed)
      .fold(0.0, (maxW, s) => s.weight > maxW ? s.weight : maxW);

  /// Total repetitions completed in this exercise
  int get totalCompletedReps =>
      sets.where((s) => s.completed).fold(0, (sum, s) => sum + s.reps);

  /// Number of completed sets
  int get completedSetsCount => sets.where((s) => s.completed).length;

  /// Total number of sets planned
  int get totalSetsCount => sets.length;

  factory WorkoutSessionExercise.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    return WorkoutSessionExercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Exercise',
      muscleGroup:
          json['muscleGroup'] as String? ??
          (json['primaryTarget'] as String? ?? 'Full Body'),
      sets: rawSets
          .map(
            (s) =>
                WorkoutSessionSet.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
      notes: json['notes'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'sets': sets.map((s) => s.toJson()).toList(),
    if (notes != null) 'notes': notes,
    'isCompleted': isCompleted,
  };

  WorkoutSessionExercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    List<WorkoutSessionSet>? sets,
    String? notes,
    bool? isCompleted,
  }) {
    return WorkoutSessionExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Explicit finite states for workout execution lifecycle.
enum WorkoutSessionState { notStarted, active, paused, completed, abandoned }

/// Domain model representing a fully executed workout session.
/// Single source of truth for completed workout performance metrics.
class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime startTime;
  final DateTime? endTime;
  final List<WorkoutSessionExercise> exercises;
  final int completedExercises;
  final double totalVolume;
  final double caloriesBurned;
  final Duration duration;
  final WorkoutSessionState state;
  final String? notes;
  final List<String> personalRecords;
  final int xpEarned;
  final double? formScore;
  final double? averageTechniqueScore;
  final List<String> aiCorrections;
  final double? readinessScore;
  final int? restingHR;
  final double? sleepQuality;
  final int? averageHR;
  final double? intensityScore;
  final String? recoveryImpact;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    this.workoutName = 'Workout Session',
    required this.startTime,
    this.endTime,
    this.exercises = const [],
    required this.completedExercises,
    required this.totalVolume,
    required this.caloriesBurned,
    required this.duration,
    this.state = WorkoutSessionState.completed,
    this.notes,
    this.personalRecords = const [],
    this.xpEarned = 0,
    this.formScore,
    this.averageTechniqueScore,
    this.aiCorrections = const [],
    this.readinessScore,
    this.restingHR,
    this.sleepQuality,
    this.averageHR,
    this.intensityScore,
    this.recoveryImpact,
  });

  /// Total volume calculated dynamically from completed sets across all exercises
  double get calculatedTotalVolume =>
      exercises.fold(0.0, (sum, ex) => sum + ex.totalVolume);

  /// Total number of sets planned across all exercises
  int get totalSetsCount =>
      exercises.fold(0, (sum, ex) => sum + ex.totalSetsCount);

  /// Total number of sets completed across all exercises
  int get completedSetsCount =>
      exercises.fold(0, (sum, ex) => sum + ex.completedSetsCount);

  /// Total reps completed across all exercises
  int get totalCompletedReps =>
      exercises.fold(0, (sum, ex) => sum + ex.totalCompletedReps);

  /// Completion percentage based on completed vs total sets
  double get completionPercentage {
    final total = totalSetsCount;
    if (total == 0) return completedExercises > 0 ? 100.0 : 0.0;
    return (completedSetsCount / total) * 100.0;
  }

  /// Duration in seconds helper
  int get durationSeconds => duration.inSeconds;

  /// Whether all exercises were completed or state is completed
  bool get completed =>
      state == WorkoutSessionState.completed || isFullyCompleted;

  /// Whether all exercises were completed
  bool get isFullyCompleted =>
      exercises.isNotEmpty && exercises.every((ex) => ex.isCompleted);

  /// Convert WorkoutSession into a WorkoutHistory record for unified history listing
  WorkoutHistory toWorkoutHistory() {
    return WorkoutHistory(
      workoutName: workoutName,
      dateCompleted: endTime ?? DateTime.now(),
      durationSeconds: duration.inSeconds,
      exercisesCompleted: completedExercises,
      completionPercentage: completionPercentage,
      totalSets: completedSetsCount,
      totalReps: totalCompletedReps,
      totalVolume: totalVolume,
      caloriesBurned: caloriesBurned,
      personalRecords: personalRecords,
      xpEarned: xpEarned,
      formScore: formScore,
      averageTechniqueScore: averageTechniqueScore,
      aiCorrections: aiCorrections,
      readinessScore: readinessScore,
      restingHR: restingHR,
      sleepQuality: sleepQuality,
      averageHR: averageHR,
      intensityScore: intensityScore,
      recoveryImpact: recoveryImpact,
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    final rawPRs = json['personalRecords'] as List<dynamic>?;
    final List<String> prsList = rawPRs != null
        ? rawPRs.map((e) => e.toString()).toList()
        : [];

    final durationSecs =
        (json['durationSeconds'] as num?)?.toInt() ??
        ((json['duration'] as num?)?.toInt() ?? 0);

    final stateStr = json['state'] as String?;
    final sessionState = stateStr != null
        ? WorkoutSessionState.values.firstWhere(
            (s) => s.name.toLowerCase() == stateStr.toLowerCase(),
            orElse: () => WorkoutSessionState.completed,
          )
        : WorkoutSessionState.completed;

    return WorkoutSession(
      id:
          json['id'] as String? ??
          'session_${DateTime.now().millisecondsSinceEpoch}',
      workoutId: json['workoutId'] as String? ?? 'default_workout',
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      exercises: rawExercises
          .map(
            (e) => WorkoutSessionExercise.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      completedExercises: (json['completedExercises'] as num?)?.toInt() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      duration: Duration(seconds: durationSecs),
      state: sessionState,
      notes: json['notes'] as String?,
      personalRecords: prsList,
      xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
      formScore: (json['formScore'] as num?)?.toDouble(),
      averageTechniqueScore: (json['averageTechniqueScore'] as num?)
          ?.toDouble(),
      aiCorrections:
          (json['aiCorrections'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      readinessScore: (json['readinessScore'] as num?)?.toDouble(),
      restingHR: (json['restingHR'] as num?)?.toInt(),
      sleepQuality: (json['sleepQuality'] as num?)?.toDouble(),
      averageHR: (json['averageHR'] as num?)?.toInt(),
      intensityScore: (json['intensityScore'] as num?)?.toDouble(),
      recoveryImpact: json['recoveryImpact'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'completedExercises': completedExercises,
    'totalVolume': totalVolume,
    'caloriesBurned': caloriesBurned,
    'durationSeconds': duration.inSeconds,
    'state': state.name,
    if (notes != null) 'notes': notes,
    'personalRecords': personalRecords,
    'xpEarned': xpEarned,
    if (formScore != null) 'formScore': formScore,
    if (averageTechniqueScore != null)
      'averageTechniqueScore': averageTechniqueScore,
    'aiCorrections': aiCorrections,
    if (readinessScore != null) 'readinessScore': readinessScore,
    if (restingHR != null) 'restingHR': restingHR,
    if (sleepQuality != null) 'sleepQuality': sleepQuality,
    if (averageHR != null) 'averageHR': averageHR,
    if (intensityScore != null) 'intensityScore': intensityScore,
    if (recoveryImpact != null) 'recoveryImpact': recoveryImpact,
  };

  WorkoutSession copyWith({
    String? id,
    String? workoutId,
    String? workoutName,
    DateTime? startTime,
    DateTime? endTime,
    List<WorkoutSessionExercise>? exercises,
    int? completedExercises,
    double? totalVolume,
    double? caloriesBurned,
    Duration? duration,
    WorkoutSessionState? state,
    String? notes,
    List<String>? personalRecords,
    int? xpEarned,
    double? formScore,
    double? averageTechniqueScore,
    List<String>? aiCorrections,
    double? readinessScore,
    int? restingHR,
    double? sleepQuality,
    int? averageHR,
    double? intensityScore,
    String? recoveryImpact,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exercises: exercises ?? this.exercises,
      completedExercises: completedExercises ?? this.completedExercises,
      totalVolume: totalVolume ?? this.totalVolume,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      duration: duration ?? this.duration,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      personalRecords: personalRecords ?? this.personalRecords,
      xpEarned: xpEarned ?? this.xpEarned,
      formScore: formScore ?? this.formScore,
      averageTechniqueScore:
          averageTechniqueScore ?? this.averageTechniqueScore,
      aiCorrections: aiCorrections ?? this.aiCorrections,
      readinessScore: readinessScore ?? this.readinessScore,
      restingHR: restingHR ?? this.restingHR,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      averageHR: averageHR ?? this.averageHR,
      intensityScore: intensityScore ?? this.intensityScore,
      recoveryImpact: recoveryImpact ?? this.recoveryImpact,
    );
  }
}
