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
  });

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
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? (exCompleted * 500.0),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? ((duration / 60.0) * 7.5),
      personalRecords: prsList,
      xpEarned: json['xpEarned'] as int? ?? ((exCompleted * 50).clamp(50, 500)),
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
      personalRecords: personalRecords ?? List.from(this.personalRecords),
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }
}
