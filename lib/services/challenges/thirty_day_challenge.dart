import '../../models/atlas_challenge.dart';
import 'atlas_challenge_service.dart';

/// One of the 30 circles.
class ChallengeDay {
  /// 0 for the first day of the challenge.
  final int index;
  final DateTime date;

  /// A workout was actually completed on this day.
  final bool done;
  final bool isToday;
  final bool isPast;

  const ChallengeDay({
    required this.index,
    required this.date,
    required this.done,
    required this.isToday,
    required this.isPast,
  });

  int get number => index + 1;

  /// A past day with no workout.
  bool get missed => isPast && !done;
}

/// What the 30-day tracker shows.
class ThirtyDayView {
  final String title;
  final DateTime startDate;
  final List<ChallengeDay> days;

  /// 1 to 30: today's day in the challenge. 30 once the challenge is over.
  final int dayNumber;
  final bool ended;

  /// True for the Showcase demo, whose progress is invented.
  final bool isSample;

  const ThirtyDayView({
    required this.title,
    required this.startDate,
    required this.days,
    required this.dayNumber,
    required this.ended,
    required this.isSample,
  });

  int get totalDays => days.length;
  int get completedDays => days.where((d) => d.done).length;

  /// Share of the 30 days with a completed workout, 0 to 100.
  int get percent =>
      totalDays == 0 ? 0 : (completedDays * 100 / totalDays).floor();

  bool get todayDone => days.any((d) => d.isToday && d.done);
}

/// Builds the 30-day tracker from the existing challenge system and the
/// recorded workouts. A day is filled only when a workout was really
/// completed on it: the calendar moving on never fills a day.
class ThirtyDayChallenge {
  const ThirtyDayChallenge._();

  static const int length = 30;
  static const String defaultTitle = '30-Day Fitness Challenge';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The athlete's own active 30-day challenge, if they accepted one.
  static AtlasChallenge? find(List<AtlasChallenge> all) {
    for (final c in all) {
      if (c.status == AtlasChallengeStatus.active &&
          !c.isSample &&
          c.durationDays == length &&
          c.startDate != null) {
        return c;
      }
    }
    return null;
  }

  /// Accepts the standard challenge through the existing challenge service,
  /// unless one is already running (so tapping twice never makes two).
  static Future<AtlasChallenge> accept(
    AtlasChallengeService service, {
    DateTime? now,
  }) async {
    final existing = find(service.all());
    if (existing != null) return existing;
    return service.create(
      title: defaultTitle,
      metric: ChallengeMetric.workouts,
      target: 20,
      durationDays: length,
      now: now,
    );
  }

  /// The tracker for [challenge], marking the days in [workoutDates] done.
  static ThirtyDayView view({
    required AtlasChallenge challenge,
    required Iterable<DateTime> workoutDates,
    required DateTime now,
    bool isSample = false,
    Set<int> extraDoneIndexes = const {},
  }) {
    final start = _day(challenge.startDate!);
    final today = _day(now);
    final done = {for (final d in workoutDates) _day(d)};
    final days = <ChallengeDay>[];
    for (var i = 0; i < length; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      days.add(
        ChallengeDay(
          index: i,
          date: date,
          done:
              !date.isAfter(today) &&
              (done.contains(date) || extraDoneIndexes.contains(i)),
          isToday: date == today,
          isPast: date.isBefore(today),
        ),
      );
    }
    final elapsed = today.difference(start).inDays + 1;
    return ThirtyDayView(
      title: challenge.title,
      startDate: start,
      days: days,
      dayNumber: elapsed < 1 ? 1 : (elapsed > length ? length : elapsed),
      ended: elapsed > length,
      isSample: isSample,
    );
  }

  /// The Showcase demo: an accepted challenge on day 12 with believable
  /// progress. It is built in memory, never saved and never read from the
  /// athlete's own challenges. Workouts completed during the demo (kept in the
  /// demo's own in-memory history) fill today's circle.
  static ThirtyDayView sample({
    required DateTime now,
    Iterable<DateTime> demoWorkoutDates = const [],
  }) {
    final today = _day(now);
    final start = DateTime(today.year, today.month, today.day - 11);
    final c = AtlasChallenge(
      id: 'sample_30_day',
      title: defaultTitle,
      metric: ChallengeMetric.workouts,
      target: 20,
      durationDays: length,
      createdAt: start,
      status: AtlasChallengeStatus.active,
      startDate: start,
      endDate: DateTime(start.year, start.month, start.day + length),
    );
    return view(
      challenge: c,
      workoutDates: demoWorkoutDates,
      now: now,
      isSample: true,
      // Days 1-3, 5-7 and 9-11 done; days 4 and 8 skipped; day 12 is today.
      extraDoneIndexes: sampleDoneIndexes,
    );
  }

  /// 0-based days the Showcase demo shows as completed.
  static const Set<int> sampleDoneIndexes = {0, 1, 2, 4, 5, 6, 8, 9, 10};
}
