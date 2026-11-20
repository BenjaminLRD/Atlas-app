import '../../models/atlas_challenge.dart';
import '../../models/workout_history.dart';
import '../../providers/fitness_provider.dart';
import '../community/sample_world.dart';
import '../steps/step_counter_service.dart';
import '../steps/step_models.dart';

/// The recorded data a challenge is measured against.
class ChallengeInputs {
  final List<WorkoutHistory> history;
  final List<DayStepTotal> stepDays;
  final DateTime now;

  const ChallengeInputs({
    required this.history,
    required this.stepDays,
    required this.now,
  });

  /// Your real workout history and step readings.
  factory ChallengeInputs.live({DateTime? now}) {
    List<DayStepTotal> steps;
    try {
      steps = StepCounterService.instance.daysBack(60);
    } catch (_) {
      steps = const [];
    }
    return ChallengeInputs(
      history: FitnessProvider.instance.workoutHistory,
      stepDays: steps,
      now: now ?? DateTime.now(),
    );
  }

  /// True when this phone has produced at least one step reading, so a
  /// step-based challenge can be measured.
  bool get stepsAvailable => stepDays.any((d) => d.steps != null);
}

/// A progress figure that may be unavailable. [value] is null when the data it
/// needs does not exist; it is never a stand-in zero.
class ChallengeProgress {
  final double? value;
  final String? note;
  const ChallengeProgress(this.value, [this.note]);
  bool get available => value != null;
}

class ChallengeProgressCalculator {
  const ChallengeProgressCalculator._();

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Your progress, counted from your own records inside the challenge window.
  static ChallengeProgress forYou(AtlasChallenge c, ChallengeInputs inputs) {
    final start = c.startDate;
    final end = c.endDate;
    if (start == null || end == null) return const ChallengeProgress(0);
    final now = inputs.now;

    bool inWindow(DateTime t) =>
        !t.isBefore(start) && t.isBefore(end) && !t.isAfter(now);

    switch (c.metric) {
      case ChallengeMetric.workouts:
        return ChallengeProgress(
          inputs.history
              .where((w) => inWindow(w.dateCompleted))
              .length
              .toDouble(),
        );
      case ChallengeMetric.minutes:
        final seconds = inputs.history
            .where((w) => inWindow(w.dateCompleted))
            .fold<int>(0, (a, w) => a + w.durationSeconds);
        return ChallengeProgress((seconds / 60).floorToDouble());
      case ChallengeMetric.volumeKg:
        return ChallengeProgress(
          inputs.history
              .where((w) => inWindow(w.dateCompleted))
              .fold<double>(0, (a, w) => a + w.totalVolume),
        );
      case ChallengeMetric.stepDays:
        final keys = <String>{
          for (var i = 0; i < c.durationDays; i++)
            stepDayKey(DateTime(start.year, start.month, start.day + i)),
        };
        final today = stepDayKey(now);
        final days = inputs.stepDays
            .where((d) => keys.contains(d.dayKey))
            .where((d) => d.dayKey.compareTo(today) <= 0)
            .toList();
        final withReading = days.where((d) => d.steps != null).toList();
        if (withReading.isEmpty) {
          return const ChallengeProgress(
            null,
            'No step readings from this phone yet, so this challenge '
            'cannot be measured. Allow activity access in Atlas.',
          );
        }
        return ChallengeProgress(
          withReading.where((d) => d.steps! >= c.stepGoal).length.toDouble(),
        );
    }
  }

  /// A sample athlete's scripted progress. It is derived from their sample
  /// stats and the elapsed time, never from a real measurement.
  static double scriptedOpponent(
    AtlasChallenge c,
    SampleAthlete a,
    DateTime now,
  ) {
    final start = c.startDate;
    final end = c.endDate;
    if (start == null || end == null) return 0;
    final last = now.isAfter(end) ? end : now;
    final elapsedDays = last.difference(start).inMinutes / 1440.0;
    if (elapsedDays <= 0) return 0;
    final s = a.stats;
    final double perDay;
    switch (c.metric) {
      case ChallengeMetric.workouts:
        perDay = s.weeklyWorkouts / 7;
      case ChallengeMetric.minutes:
        perDay = s.weeklyMinutes / 7;
      case ChallengeMetric.volumeKg:
        perDay = s.totalWorkouts == 0
            ? 0
            : (s.totalVolumeKg / s.totalWorkouts) * s.weeklyWorkouts / 7;
      case ChallengeMetric.stepDays:
        perDay = (s.avgDailySteps / c.stepGoal).clamp(0.0, 1.0);
    }
    var v = perDay * elapsedDays;
    if (c.metric == ChallengeMetric.workouts ||
        c.metric == ChallengeMetric.stepDays) {
      v = v.floorToDouble();
    } else {
      v = v.roundToDouble();
    }
    return v > c.target ? c.target : v;
  }
}
