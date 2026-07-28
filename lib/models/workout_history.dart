class WorkoutHistory {
  final String workoutName;
  final DateTime dateCompleted;
  final int durationSeconds;
  final int exercisesCompleted;
  final double completionPercentage;

  const WorkoutHistory({
    required this.workoutName,
    required this.dateCompleted,
    required this.durationSeconds,
    required this.exercisesCompleted,
    required this.completionPercentage,
  });

  Map<String, dynamic> toJson() => {
        'workoutName': workoutName,
        'dateCompleted': dateCompleted.toIso8601String(),
        'durationSeconds': durationSeconds,
        'exercisesCompleted': exercisesCompleted,
        'completionPercentage': completionPercentage,
      };

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    return WorkoutHistory(
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      dateCompleted: DateTime.parse(json['dateCompleted'] as String),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      exercisesCompleted: json['exercisesCompleted'] as int? ?? 0,
      completionPercentage:
          (json['completionPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
