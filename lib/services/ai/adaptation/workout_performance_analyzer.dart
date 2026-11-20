import '../memory/fitness_memory.dart';
import 'training_adjustment.dart';

/// Detailed execution telemetry for a single exercise within a completed workout.
class ExercisePerformance {
  final String exerciseName;
  final int plannedSets;
  final int completedSets;
  final int targetReps;
  final int actualReps;
  final double targetWeight;
  final double actualWeight;
  final double? rpe; // 1.0 to 10.0 Rate of Perceived Exertion
  final int? restSeconds;
  final bool wasSkipped;
  final bool wasReplaced;
  final String? replacedWith;

  const ExercisePerformance({
    required this.exerciseName,
    this.plannedSets = 3,
    this.completedSets = 3,
    this.targetReps = 10,
    this.actualReps = 10,
    this.targetWeight = 40.0,
    this.actualWeight = 40.0,
    this.rpe,
    this.restSeconds,
    this.wasSkipped = false,
    this.wasReplaced = false,
    this.replacedWith,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'plannedSets': plannedSets,
    'completedSets': completedSets,
    'targetReps': targetReps,
    'actualReps': actualReps,
    'targetWeight': targetWeight,
    'actualWeight': actualWeight,
    'rpe': rpe,
    'restSeconds': restSeconds,
    'wasSkipped': wasSkipped,
    'wasReplaced': wasReplaced,
    'replacedWith': replacedWith,
  };

  factory ExercisePerformance.fromJson(Map<String, dynamic> json) {
    return ExercisePerformance(
      exerciseName: json['exerciseName'] as String? ?? '',
      plannedSets: (json['plannedSets'] as num?)?.toInt() ?? 3,
      completedSets: (json['completedSets'] as num?)?.toInt() ?? 3,
      targetReps: (json['targetReps'] as num?)?.toInt() ?? 10,
      actualReps: (json['actualReps'] as num?)?.toInt() ?? 10,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 40.0,
      actualWeight: (json['actualWeight'] as num?)?.toDouble() ?? 40.0,
      rpe: (json['rpe'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
      wasSkipped: json['wasSkipped'] as bool? ?? false,
      wasReplaced: json['wasReplaced'] as bool? ?? false,
      replacedWith: json['replacedWith'] as String?,
    );
  }
}

/// Aggregated performance summary of a completed workout session.
class WorkoutPerformanceData {
  final String workoutName;
  final DateTime dateCompleted;
  final int plannedDurationMinutes;
  final int actualDurationMinutes;
  final List<ExercisePerformance> exercises;
  final double? overallRpe;
  final String? userFeedback; // 'too_easy', 'perfect', 'too_hard'

  const WorkoutPerformanceData({
    required this.workoutName,
    required this.dateCompleted,
    this.plannedDurationMinutes = 45,
    this.actualDurationMinutes = 45,
    this.exercises = const [],
    this.overallRpe,
    this.userFeedback,
  });

  Map<String, dynamic> toJson() => {
    'workoutName': workoutName,
    'dateCompleted': dateCompleted.toIso8601String(),
    'plannedDurationMinutes': plannedDurationMinutes,
    'actualDurationMinutes': actualDurationMinutes,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'overallRpe': overallRpe,
    'userFeedback': userFeedback,
  };

  factory WorkoutPerformanceData.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List? ?? const [];
    final exercisesList = rawExercises
        .map(
          (e) =>
              ExercisePerformance.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return WorkoutPerformanceData(
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      dateCompleted: DateTime.parse(json['dateCompleted'] as String),
      plannedDurationMinutes:
          (json['plannedDurationMinutes'] as num?)?.toInt() ?? 45,
      actualDurationMinutes:
          (json['actualDurationMinutes'] as num?)?.toInt() ?? 45,
      exercises: exercisesList,
      overallRpe: (json['overallRpe'] as num?)?.toDouble(),
      userFeedback: json['userFeedback'] as String?,
    );
  }
}

/// Analyzer that inspects completed workout telemetry to detect training signals:
/// 'Too Easy', 'Too Difficult', 'Plateau', and 'Preference Learning'.
class WorkoutPerformanceAnalyzer {
  final FitnessMemory _fitnessMemory;

  WorkoutPerformanceAnalyzer({FitnessMemory? fitnessMemory})
    : _fitnessMemory = fitnessMemory ?? FitnessMemory.instance;

  /// Analyzes a single completed workout performance record and produces adjustments.
  Future<List<TrainingAdjustment>> analyzeSession(
    WorkoutPerformanceData performance,
  ) async {
    final adjustments = <TrainingAdjustment>[];

    for (final ex in performance.exercises) {
      // 1. Exercise Replacement Preference Learning
      if (ex.wasReplaced &&
          ex.replacedWith != null &&
          ex.replacedWith!.isNotEmpty) {
        await _fitnessMemory.recordExerciseReplacement(
          oldExercise: ex.exerciseName,
          newExercise: ex.replacedWith!,
        );
        adjustments.add(
          TrainingAdjustment(
            adjustmentType: AdjustmentType.exerciseSwap,
            affectedExercise: ex.exerciseName,
            recommendedChange:
                'Replace with ${ex.replacedWith} based on athlete preference.',
            reason: 'Exercise was substituted during training.',
            suggestedReplacement: ex.replacedWith,
            confidence: 0.95,
          ),
        );
        continue;
      }

      // 2. Skipped Exercise Handling
      if (ex.wasSkipped) {
        await _fitnessMemory.recordExercisePreference(
          exercise: ex.exerciseName,
          isPreferred: false,
        );
        adjustments.add(
          TrainingAdjustment(
            adjustmentType: AdjustmentType.exerciseSwap,
            affectedExercise: ex.exerciseName,
            recommendedChange:
                'Substitute ${ex.exerciseName} with a preferred alternative.',
            reason: 'Exercise was skipped by athlete.',
            confidence: 0.85,
          ),
        );
        continue;
      }

      // 3. Too Easy Detection
      final isTooEasy =
          (ex.actualReps >= ex.targetReps + 3) ||
          (ex.rpe != null && ex.rpe! < 6.0) ||
          (performance.userFeedback == 'too_easy');

      if (isTooEasy) {
        final increaseAmount = (ex.actualWeight * 0.05).clamp(1.25, 10.0);
        final roundedIncrease =
            (increaseAmount * 2).round() / 2; // Round to nearest 0.5kg
        adjustments.add(
          TrainingAdjustment(
            adjustmentType: AdjustmentType.increaseWeight,
            affectedExercise: ex.exerciseName,
            recommendedChange:
                'Increase ${ex.exerciseName} load by 5% (+${roundedIncrease}kg).',
            reason: 'Target exceeded with low RPE (${ex.rpe ?? 5.5}).',
            weightMultiplier: 1.05,
            confidence: 0.95,
          ),
        );
        continue;
      }

      // 4. Too Difficult Detection
      final isTooDifficult =
          (ex.completedSets < ex.plannedSets) ||
          (ex.actualReps <= ex.targetReps - 2) ||
          (ex.rpe != null && ex.rpe! > 9.0) ||
          (performance.userFeedback == 'too_hard');

      if (isTooDifficult) {
        if (ex.completedSets < ex.plannedSets) {
          adjustments.add(
            TrainingAdjustment(
              adjustmentType: AdjustmentType.decreaseVolume,
              affectedExercise: ex.exerciseName,
              recommendedChange:
                  'Reduce volume by 1 set on ${ex.exerciseName} to manage fatigue.',
              reason:
                  'Incomplete sets detected (${ex.completedSets}/${ex.plannedSets}).',
              setsDelta: -1,
              confidence: 0.90,
            ),
          );
        } else {
          adjustments.add(
            TrainingAdjustment(
              adjustmentType: AdjustmentType.decreaseWeight,
              affectedExercise: ex.exerciseName,
              recommendedChange:
                  'Reduce load by 10% on ${ex.exerciseName} to secure clean technique.',
              reason:
                  'Missed rep targets or high exertion (RPE ${ex.rpe ?? 9.5}).',
              weightMultiplier: 0.90,
              confidence: 0.90,
            ),
          );
        }
      }
    }

    return adjustments;
  }

  /// Detects plateau across a multi-session history of the same exercise.
  List<TrainingAdjustment> detectPlateaus(
    List<WorkoutPerformanceData> history,
  ) {
    final adjustments = <TrainingAdjustment>[];
    if (history.length < 3) return adjustments;

    // Group performances by exercise name
    final exerciseHistoryMap = <String, List<ExercisePerformance>>{};
    for (final session in history) {
      for (final ex in session.exercises) {
        if (!ex.wasSkipped && !ex.wasReplaced) {
          exerciseHistoryMap.putIfAbsent(ex.exerciseName, () => []).add(ex);
        }
      }
    }

    // Check for 3 consecutive sessions with 0 progression in weight and reps
    for (final entry in exerciseHistoryMap.entries) {
      final logs = entry.value;
      if (logs.length >= 3) {
        final recent3 = logs.take(3).toList();
        final first = recent3[0];
        final allSameWeight = recent3.every(
          (e) => (e.actualWeight - first.actualWeight).abs() < 0.5,
        );
        final allSameReps = recent3.every(
          (e) => e.actualReps == first.actualReps,
        );

        if (allSameWeight && allSameReps) {
          adjustments.add(
            TrainingAdjustment(
              adjustmentType: AdjustmentType.plateauBreak,
              affectedExercise: entry.key,
              recommendedChange:
                  'Plateau detected on ${entry.key}. Change stimulus by altering rep bracket or switching to an adjacent variation.',
              reason:
                  'Static load (${first.actualWeight}kg x ${first.actualReps} reps) over 3 consecutive sessions.',
              confidence: 0.92,
            ),
          );
        }
      }
    }

    return adjustments;
  }
}
