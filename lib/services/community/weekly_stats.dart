import '../../models/activity_record.dart';
import '../../models/workout_history.dart';
import '../steps/step_models.dart';

/// Totals for one Monday to Sunday week, computed only from recorded
/// activity. A null value means "no record" (shown as a dash), which is
/// different from a recorded zero.
class WeekStats {
  /// Monday 00:00 (local) of this week.
  final DateTime start;
  final int? workouts;
  final int? minutes;
  final double? volumeKg;

  /// Average steps per day over the days that have a step reading, or null
  /// when no day this week has one.
  final int? avgDailySteps;

  /// How many days of this week had a step reading.
  final int stepDays;

  /// Distance of the GPS runs and rides recorded this week, or null when none
  /// was recorded. Cardio sessions are separate from strength workouts, so
  /// they are never counted in [workouts], [minutes] or [volumeKg] and one
  /// activity can never be counted twice.
  final double? cardioKm;

  /// How many GPS runs and rides were recorded this week (null when none).
  final int? cardioSessions;

  const WeekStats({
    required this.start,
    this.workouts,
    this.minutes,
    this.volumeKg,
    this.avgDailySteps,
    this.stepDays = 0,
    this.cardioKm,
    this.cardioSessions,
  });

  DateTime get endExclusive => start.add(const Duration(days: 7));
}

/// The current and previous week side by side, plus the streak.
class MyWeekly {
  final WeekStats current;
  final WeekStats previous;

  /// Current workout streak in days, or null when no workout is recorded.
  final int? streakDays;

  /// True when at least one step reading exists in either week.
  final bool hasAnySteps;

  /// True when at least one workout has ever been recorded.
  final bool hasAnyWorkouts;

  const MyWeekly({
    required this.current,
    required this.previous,
    required this.streakDays,
    required this.hasAnySteps,
    required this.hasAnyWorkouts,
  });
}

/// Builds weekly stats from the workout history and the step ledger.
class WeeklyStats {
  const WeeklyStats._();

  /// Monday 00:00 (local) of the week containing [d].
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Totals for the week starting [start]. [history] empty means nothing was
  /// ever recorded, so workout figures are null; a week with no workouts when
  /// there is history is a genuine zero.
  static WeekStats forWeek({
    required List<WorkoutHistory> history,
    required DateTime start,
    List<DayStepTotal> stepDays = const [],
    List<CardioSession> cardio = const [],
    DateTime? now,
  }) {
    final end = start.add(const Duration(days: 7));
    // Each session id is counted once, however often it appears.
    final seen = <String>{};
    final cardioInWeek = [
      for (final c in cardio)
        if (c.kind != null &&
            c.isCompleted &&
            !c.startTime.isBefore(start) &&
            c.startTime.isBefore(end) &&
            seen.add(c.id))
          c,
    ];
    final inWeek = [
      for (final w in history)
        if (!w.dateCompleted.isBefore(start) && w.dateCompleted.isBefore(end))
          w,
    ];
    final hasHistory = history.isNotEmpty;

    final keys = {
      for (var i = 0; i < 7; i++)
        stepDayKey(DateTime(start.year, start.month, start.day + i)),
    };
    final today = stepDayStart(now ?? DateTime.now());
    final withSteps = [
      for (final d in stepDays)
        if (keys.contains(d.dayKey) &&
            d.steps != null &&
            !_dayAfter(d.dayKey, today))
          d.steps!,
    ];
    final avg = withSteps.isEmpty
        ? null
        : (withSteps.fold<int>(0, (a, b) => a + b) / withSteps.length).round();

    return WeekStats(
      start: start,
      workouts: hasHistory ? inWeek.length : null,
      minutes: hasHistory
          ? (inWeek.fold<int>(0, (a, w) => a + w.durationSeconds) / 60).round()
          : null,
      volumeKg: hasHistory
          ? inWeek.fold<double>(0, (a, w) => a + w.totalVolume)
          : null,
      avgDailySteps: avg,
      stepDays: withSteps.length,
      cardioKm: cardioInWeek.isEmpty
          ? null
          : cardioInWeek.fold<double>(0, (a, c) => a + c.distanceKm),
      cardioSessions: cardioInWeek.isEmpty ? null : cardioInWeek.length,
    );
  }

  static bool _dayAfter(String dayKey, DateTime today) =>
      dayKey.compareTo(stepDayKey(today)) > 0;

  static MyWeekly build({
    required List<WorkoutHistory> history,
    required int? streakDays,
    required List<DayStepTotal> stepDays,
    List<CardioSession> cardio = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final thisWeek = weekStart(clock);
    final lastWeek = thisWeek.subtract(const Duration(days: 7));
    final current = forWeek(
      history: history,
      start: thisWeek,
      stepDays: stepDays,
      cardio: cardio,
      now: clock,
    );
    final previous = forWeek(
      history: history,
      start: lastWeek,
      stepDays: stepDays,
      cardio: cardio,
      now: clock,
    );
    return MyWeekly(
      current: current,
      previous: previous,
      streakDays: history.isEmpty ? null : streakDays,
      hasAnySteps: current.stepDays + previous.stepDays > 0,
      hasAnyWorkouts: history.isNotEmpty,
    );
  }
}
