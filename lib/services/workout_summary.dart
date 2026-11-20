import '../models/personal_record.dart';
import '../models/workout_history.dart';
import '../models/workout_session.dart';
import 'exercise/muscle_map.dart';
import 'progressive_overload_service.dart';
import 'workout_streak_service.dart';

/// One personal record achieved in the session, ready to show.
class SummaryPersonalRecord {
  final String exerciseName;
  final String type;
  final String valueText;

  /// How much it improved on the previous best, or null when that is unknown.
  final double? improvementPercent;

  const SummaryPersonalRecord({
    required this.exerciseName,
    required this.type,
    required this.valueText,
    this.improvementPercent,
  });

  factory SummaryPersonalRecord.fromRecord(PersonalRecord r) =>
      SummaryPersonalRecord(
        exerciseName: r.exerciseName,
        type: r.recordType,
        valueText: r.formattedValue,
        improvementPercent: r.previousValue > 0
            ? r.improvementPercentage
            : null,
      );
}

/// Everything the post-workout summary shows, worked out from the finished
/// session and the saved history. A value that cannot be known is `null`, never
/// zero: the screen shows a dash for it. A real zero stays `0`.
class WorkoutSummaryData {
  final String workoutName;
  final DateTime completedAt;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;

  final int exercisesCompleted;
  final int exercisesTotal;
  final int setsCompleted;
  final int setsTotal;

  /// Total weight lifted. `null` when no finished set had a load, as in a
  /// bodyweight or cardio session, where the figure would be meaningless.
  final double? totalVolumeKg;

  /// Estimated calories, or `null` when the session had no estimate.
  final int? caloriesEstimate;

  /// XP awarded for this workout, `null` when none was awarded now (a
  /// workout that was already recorded).
  final int? xpEarned;

  final List<SummaryPersonalRecord> personalRecords;

  /// Days in a row with a workout, only when the saved history shows it.
  final int? streakDays;

  /// Average time of the sets that were timed, or `null` when none was.
  final double? averageSetSeconds;

  /// Muscles worked by the exercises with at least one finished set.
  final MuscleActivation muscles;

  const WorkoutSummaryData({
    required this.workoutName,
    required this.completedAt,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.exercisesCompleted,
    required this.exercisesTotal,
    required this.setsCompleted,
    required this.setsTotal,
    this.totalVolumeKg,
    this.caloriesEstimate,
    this.xpEarned,
    this.personalRecords = const [],
    this.streakDays,
    this.averageSetSeconds,
    this.muscles = MuscleActivation.empty,
  });
}

/// Builds [WorkoutSummaryData] from facts that already exist.
class WorkoutSummaryBuilder {
  const WorkoutSummaryBuilder._();

  static WorkoutSummaryData build({
    required WorkoutSession session,
    List<PersonalRecordResult> personalRecords = const [],
    int? streakDays,
    int? xpEarned,
    int? caloriesEstimate,
  }) {
    var setsTotal = 0;
    var setsCompleted = 0;
    var loadedSets = 0;
    var volume = 0.0;
    var timedSets = 0;
    var timedSeconds = 0;
    final worked = <MuscleActivation>[];

    for (final ex in session.exercises) {
      var exerciseDone = 0;
      for (final s in ex.sets) {
        setsTotal++;
        if (!s.completed) continue;
        setsCompleted++;
        exerciseDone++;
        if (s.weight > 0) {
          loadedSets++;
          volume += s.weight * s.reps;
        }
        final d = s.durationSeconds;
        if (d != null) {
          timedSets++;
          timedSeconds += d;
        }
      }
      if (exerciseDone > 0) {
        worked.add(
          MuscleMap.forPlanExercise({
            'id': ex.id,
            'primaryTarget': ex.muscleGroup,
          }),
        );
      }
    }

    final exercisesCompleted = session.exercises.isEmpty
        ? session.completedExercises
        : session.exercises.where((e) => e.isCompleted).length;

    return WorkoutSummaryData(
      workoutName: session.workoutName,
      completedAt: session.endTime ?? session.startTime.add(session.duration),
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      exercisesCompleted: exercisesCompleted,
      exercisesTotal: session.exercises.length,
      setsCompleted: setsCompleted,
      setsTotal: setsTotal,
      totalVolumeKg: loadedSets > 0 ? volume : null,
      caloriesEstimate: caloriesEstimate,
      xpEarned: xpEarned,
      personalRecords: [
        for (final p in personalRecords)
          SummaryPersonalRecord.fromRecord(p.record),
      ],
      streakDays: streakDays,
      averageSetSeconds: timedSets > 0 ? timedSeconds / timedSets : null,
      muscles: MuscleActivation.combine(worked),
    );
  }

  /// The current streak, but only when [history] really contains the workout
  /// that was just finished (so a workout that was not saved never claims a
  /// streak) and the streak is at least one day.
  static int? streakFor(List<WorkoutHistory> history, WorkoutHistory saved) {
    final contains = history.any(
      (h) =>
          h.workoutName == saved.workoutName &&
          h.dateCompleted == saved.dateCompleted,
    );
    if (!contains) return null;
    final days = const WorkoutStreakService()
        .calculateStreak(history)
        .currentStreak;
    return days >= 1 ? days : null;
  }
}
