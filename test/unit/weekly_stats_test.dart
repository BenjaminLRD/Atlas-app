import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/community/weekly_stats.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-16 is a Monday.
final _mon = DateTime(2026, 11, 16);

WorkoutHistory _w(DateTime at, {int seconds = 3600, double volume = 1000}) =>
    WorkoutHistory(
      workoutName: 'Session',
      dateCompleted: at,
      durationSeconds: seconds,
      exercisesCompleted: 3,
      completionPercentage: 100,
      totalVolume: volume,
      totalSets: 9,
      totalReps: 90,
    );

DayStepTotal _steps(DateTime day, int? steps) =>
    DayStepTotal(dayKey: stepDayKey(day), steps: steps);

void main() {
  group('Monday to Sunday weeks', () {
    test('weekStart is the Monday 00:00 of the week for every weekday', () {
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 11, 16 + i, 15, 30);
        expect(WeeklyStats.weekStart(day), _mon, reason: 'day $i');
      }
      expect(
        WeeklyStats.weekStart(DateTime(2026, 11, 15, 23, 59)),
        DateTime(2026, 11, 9),
      );
      expect(
        WeeklyStats.weekStart(DateTime(2026, 11, 23)),
        DateTime(2026, 11, 23),
      );
    });

    test(
      'Sunday 23:59:59 belongs to the old week, Monday 00:00 to the new one',
      () {
        final history = [
          _w(DateTime(2026, 11, 15, 23, 59, 59)), // Sunday, previous week
          _w(DateTime(2026, 11, 16, 0, 0, 0)), // Monday, this week
          _w(DateTime(2026, 11, 22, 23, 59, 59)), // Sunday, this week
          _w(DateTime(2026, 11, 23, 0, 0, 0)), // next Monday, next week
        ];
        final week = WeeklyStats.build(
          history: history,
          streakDays: 2,
          stepDays: const [],
          now: DateTime(2026, 11, 18, 12),
        );
        expect(week.current.start, _mon);
        expect(week.current.workouts, 2);
        expect(week.previous.workouts, 1);
      },
    );

    test('minutes and volume are summed from real sessions', () {
      final week = WeeklyStats.build(
        history: [
          _w(DateTime(2026, 11, 16, 8), seconds: 2700, volume: 4000),
          _w(DateTime(2026, 11, 17, 8), seconds: 3000, volume: 6500.5),
        ],
        streakDays: 2,
        stepDays: const [],
        now: DateTime(2026, 11, 18),
      );
      expect(week.current.minutes, 95);
      expect(week.current.volumeKg, 10500.5);
      expect(week.streakDays, 2);
    });
  });

  group('empty and missing data', () {
    test('no history at all: everything is no record, never zero', () {
      final week = WeeklyStats.build(
        history: const [],
        streakDays: 5, // ignored without any workout
        stepDays: const [],
        now: DateTime(2026, 11, 18),
      );
      expect(week.hasAnyWorkouts, isFalse);
      expect(week.current.workouts, isNull);
      expect(week.current.minutes, isNull);
      expect(week.current.volumeKg, isNull);
      expect(week.previous.workouts, isNull);
      expect(week.streakDays, isNull);
      expect(week.current.avgDailySteps, isNull);
    });

    test('history exists but this week is empty: a genuine zero', () {
      final week = WeeklyStats.build(
        history: [_w(DateTime(2026, 11, 3, 9))],
        streakDays: 0,
        stepDays: const [],
        now: DateTime(2026, 11, 18),
      );
      expect(week.hasAnyWorkouts, isTrue);
      expect(week.current.workouts, 0);
      expect(week.current.minutes, 0);
      expect(week.previous.workouts, 0);
    });
  });

  group('steps', () {
    test('unavailable sensor means no steps, not zero', () {
      final week = WeeklyStats.build(
        history: [_w(DateTime(2026, 11, 16, 9))],
        streakDays: 1,
        stepDays: [
          for (var i = 0; i < 14; i++) _steps(DateTime(2026, 11, 5 + i), null),
        ],
        now: DateTime(2026, 11, 18),
      );
      expect(week.hasAnySteps, isFalse);
      expect(week.current.avgDailySteps, isNull);
      expect(week.current.stepDays, 0);
    });

    test('the average uses only days with a reading and skips future days', () {
      final week = WeeklyStats.build(
        history: [_w(DateTime(2026, 11, 16, 9))],
        streakDays: 1,
        stepDays: [
          _steps(DateTime(2026, 11, 16), 8000),
          _steps(DateTime(2026, 11, 17), null),
          _steps(DateTime(2026, 11, 18), 6001),
          _steps(DateTime(2026, 11, 20), 99999), // future relative to now
        ],
        now: DateTime(2026, 11, 18, 20),
      );
      expect(week.current.stepDays, 2);
      expect(week.current.avgDailySteps, 7001); // (8000 + 6001) / 2, rounded
      expect(week.hasAnySteps, isTrue);
    });

    test('last week steps are kept apart from this week', () {
      final week = WeeklyStats.build(
        history: [_w(DateTime(2026, 11, 10, 9))],
        streakDays: 0,
        stepDays: [
          _steps(DateTime(2026, 11, 10), 5000),
          _steps(DateTime(2026, 11, 11), 7000),
          _steps(DateTime(2026, 11, 16), 10000),
        ],
        now: DateTime(2026, 11, 18),
      );
      expect(week.previous.avgDailySteps, 6000);
      expect(week.current.avgDailySteps, 10000);
    });
  });
}
