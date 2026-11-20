import 'dart:math';
import '../models/streak_data.dart';
import '../models/workout_history.dart';

/// Representation of a single day in the weekly streak activity calendar
class WeeklyDayActivity {
  final String dayLabel; // 'M', 'T', 'W', 'T', 'F', 'S', 'S'
  final DateTime date;
  final bool isCompleted;
  final bool isToday;
  final bool isPast;
  final bool isFuture;

  const WeeklyDayActivity({
    required this.dayLabel,
    required this.date,
    required this.isCompleted,
    required this.isToday,
    required this.isPast,
    required this.isFuture,
  });

  int get dayNumber => date.day;
}

/// Service responsible for calculating workout streaks, longest streak records,
/// and weekly activity calendar visualization from actual workout completion logs.
class WorkoutStreakService {
  const WorkoutStreakService();

  /// Converts a DateTime into a date-only DateTime (midnight local time)
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Calculates [StreakData] from a list of [WorkoutHistory] items.
  StreakData calculateStreak(
    List<WorkoutHistory> history, {
    DateTime? referenceDate,
  }) {
    final dates = history.map((w) => w.dateCompleted).toList();
    return calculateFromDates(dates, referenceDate: referenceDate);
  }

  /// Calculates [StreakData] from raw workout completion dates.
  StreakData calculateFromDates(
    List<DateTime> completedDates, {
    DateTime? referenceDate,
  }) {
    if (completedDates.isEmpty) {
      return StreakData.initial();
    }

    final Set<DateTime> uniqueDateOnlySet = completedDates
        .map((d) => toDateOnly(d))
        .toSet();

    final List<DateTime> sortedDatesDesc = uniqueDateOnlySet.toList()
      ..sort((a, b) => b.compareTo(a));

    final now = toDateOnly(referenceDate ?? DateTime.now());
    final yesterday = now.subtract(const Duration(days: 1));

    // Calculate current streak
    int currentStreak = 0;
    DateTime? checkDate;

    if (uniqueDateOnlySet.contains(now)) {
      // User worked out today
      checkDate = now;
    } else if (uniqueDateOnlySet.contains(yesterday)) {
      // User worked out yesterday, today is still in progress
      checkDate = yesterday;
    }

    if (checkDate != null) {
      DateTime runner = checkDate;
      while (uniqueDateOnlySet.contains(runner)) {
        currentStreak++;
        runner = runner.subtract(const Duration(days: 1));
      }
    }

    // Calculate longest streak across entire history
    int longestStreak = 0;
    final List<DateTime> sortedAsc = uniqueDateOnlySet.toList()..sort();

    int runningStreak = 0;
    DateTime? prevDate;

    for (final d in sortedAsc) {
      if (prevDate == null) {
        runningStreak = 1;
      } else {
        final diff = d.difference(prevDate).inDays;
        if (diff == 1) {
          runningStreak++;
        } else if (diff > 1) {
          runningStreak = 1;
        }
      }
      longestStreak = max(longestStreak, runningStreak);
      prevDate = d;
    }

    longestStreak = max(longestStreak, currentStreak);

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastWorkoutDate: sortedDatesDesc.first,
    );
  }

  /// Builds a 7-day Monday-to-Sunday weekly activity calendar for the week
  /// containing [referenceDate].
  List<WeeklyDayActivity> getWeeklyCalendar(
    List<WorkoutHistory> history, {
    DateTime? referenceDate,
  }) {
    final dates = history.map((w) => w.dateCompleted).toList();
    return getWeeklyCalendarFromDates(dates, referenceDate: referenceDate);
  }

  /// Builds a 7-day Monday-to-Sunday weekly activity calendar from raw dates.
  List<WeeklyDayActivity> getWeeklyCalendarFromDates(
    List<DateTime> completedDates, {
    DateTime? referenceDate,
  }) {
    final now = toDateOnly(referenceDate ?? DateTime.now());
    final uniqueSet = completedDates.map((d) => toDateOnly(d)).toSet();

    // Monday of current week (DateTime.weekday: 1=Mon ... 7=Sun)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return List.generate(7, (index) {
      final dayDate = monday.add(Duration(days: index));
      final isToday = dayDate == now;
      final isPast = dayDate.isBefore(now);
      final isFuture = dayDate.isAfter(now);
      final isCompleted = uniqueSet.contains(dayDate);

      return WeeklyDayActivity(
        dayLabel: weekLabels[index],
        date: dayDate,
        isCompleted: isCompleted,
        isToday: isToday,
        isPast: isPast,
        isFuture: isFuture,
      );
    });
  }
}
