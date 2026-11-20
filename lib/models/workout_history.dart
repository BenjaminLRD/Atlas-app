import 'workout_session.dart';

/// Enhanced WorkoutHistory model carrying detailed workout metrics for analytics and gamification.
class WorkoutHistory {
  final String workoutName;
  final DateTime dateCompleted;
  final int durationSeconds;
  final int exercisesCompleted;
  final double completionPercentage;
  final int totalSets;
  final int totalReps;
  final double totalVolume;
  final double caloriesBurned;
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
  final List<WorkoutSessionExercise>? sessionExercises;

  const WorkoutHistory({
    required this.workoutName,
    required this.dateCompleted,
    required this.durationSeconds,
    required this.exercisesCompleted,
    required this.completionPercentage,
    this.totalSets = 0,
    this.totalReps = 0,
    this.totalVolume = 0.0,
    this.caloriesBurned = 0.0,
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
    this.sessionExercises,
  });

  /// Convenience getter for exercise session details
  List<WorkoutSessionExercise> get exercises => sessionExercises ?? const [];

  Map<String, dynamic> toJson() => {
    'workoutName': workoutName,
    'dateCompleted': dateCompleted.toIso8601String(),
    'durationSeconds': durationSeconds,
    'exercisesCompleted': exercisesCompleted,
    'completionPercentage': completionPercentage,
    'totalSets': totalSets,
    'totalReps': totalReps,
    'totalVolume': totalVolume,
    'caloriesBurned': caloriesBurned,
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
    if (sessionExercises != null)
      'sessionExercises': sessionExercises!.map((e) => e.toJson()).toList(),
  };

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    final exCompleted = json['exercisesCompleted'] as int? ?? 0;
    final duration = json['durationSeconds'] as int? ?? 0;
    final compPct = (json['completionPercentage'] as num?)?.toDouble() ?? 0.0;

    final rawPRs = json['personalRecords'] as List?;
    final List<String> prsList = rawPRs != null
        ? rawPRs.map((e) => e.toString()).toList()
        : [];

    return WorkoutHistory(
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      dateCompleted: DateTime.parse(json['dateCompleted'] as String),
      durationSeconds: duration,
      exercisesCompleted: exCompleted,
      completionPercentage: compPct,
      totalSets: json['totalSets'] as int? ?? (exCompleted * 4),
      totalReps: json['totalReps'] as int? ?? (exCompleted * 40),
      totalVolume:
          (json['totalVolume'] as num?)?.toDouble() ?? (exCompleted * 500.0),
      caloriesBurned:
          (json['caloriesBurned'] as num?)?.toDouble() ??
          ((duration / 60.0) * 7.5),
      personalRecords: prsList,
      xpEarned: json['xpEarned'] as int? ?? ((exCompleted * 50).clamp(50, 500)),
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
      sessionExercises: (json['sessionExercises'] as List<dynamic>?)
          ?.map(
            (e) => WorkoutSessionExercise.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  WorkoutHistory copyWith({
    String? workoutName,
    DateTime? dateCompleted,
    int? durationSeconds,
    int? exercisesCompleted,
    double? completionPercentage,
    int? totalSets,
    int? totalReps,
    double? totalVolume,
    double? caloriesBurned,
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
    List<WorkoutSessionExercise>? sessionExercises,
  }) {
    return WorkoutHistory(
      workoutName: workoutName ?? this.workoutName,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      exercisesCompleted: exercisesCompleted ?? this.exercisesCompleted,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      totalSets: totalSets ?? this.totalSets,
      totalReps: totalReps ?? this.totalReps,
      totalVolume: totalVolume ?? this.totalVolume,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
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
      sessionExercises: sessionExercises ?? this.sessionExercises,
    );
  }
}
