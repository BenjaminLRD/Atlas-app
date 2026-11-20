import '../../models/hydration.dart';
import '../../providers/showcase_data_provider.dart';
import 'hydration_goal_calculator.dart';
import 'hydration_service.dart';

/// Sample hydration for Showcase Mode.
///
/// Invented demonstration data for the sample athlete, never a measurement and
/// never written to a real account. Targets are worked out with the real
/// calculator from the sample athlete's own weight and sample workouts, so a
/// day with a workout has an activity-adjusted target like it would for a real
/// user. The week shows a completed day, partial days, one day with no record
/// and today in progress.
class SampleHydration {
  const SampleHydration._();

  /// The id every sample record carries.
  static const String userId = 'sample';

  // Intake as a share of that day's target; null means no record that day.
  // Index = days ago (1..6).
  static const Map<int, double?> _share = {
    1: 1.06,
    2: 0.68,
    3: 0.97,
    4: null,
    5: 0.82,
    6: 1.0,
  };

  static const List<int> _chunks = [250, 250, 300, 250, 400, 250, 250, 300];
  static const List<(int, int)> _times = [
    (7, 40),
    (9, 15),
    (10, 50),
    (12, 30),
    (14, 5),
    (15, 45),
    (17, 20),
    (19, 10),
    (20, 40),
  ];

  static HydrationStore build({
    required DateTime now,
    required double? weightKg,
  }) {
    final store = HydrationStore();
    final workouts = ShowcaseDataProvider.instance.getShowcaseWorkoutHistory();
    List<HydrationActivity> activitiesOn(String key) => [
      for (final w in workouts)
        if (hydrationDayKey(w.dateCompleted) == key)
          HydrationActivity(
            id: 'w|${w.workoutName}|${w.dateCompleted.millisecondsSinceEpoch}',
            minutes: (w.durationSeconds / 60).round(),
            cardio: false,
          ),
    ];

    for (var ago = 6; ago >= 1; ago--) {
      final date = DateTime(now.year, now.month, now.day - ago);
      final key = hydrationDayKey(date);
      final goal = HydrationGoalCalculator.calculate(
        weightKg: weightKg,
        activities: activitiesOn(key),
      );
      store.goals['$userId|$key'] = goal;
      final share = _share[ago];
      if (share == null) continue;
      final total = ((goal.goalMl * share) / 10).round() * 10;
      var left = total;
      var i = 0;
      while (left > 0 && i < _times.length) {
        final ml = left < _chunks[i % _chunks.length]
            ? left
            : _chunks[i % _chunks.length];
        final t = _times[i];
        final at = DateTime(date.year, date.month, date.day, t.$1, t.$2);
        store.entries.add(
          HydrationEntry(
            id: 'sample_${key}_$i',
            userId: userId,
            amountMl: ml,
            loggedAt: at,
            dayKey: key,
          ),
        );
        left -= ml;
        i++;
      }
      // Anything left after the last time slot goes into the final entry.
      if (left > 0 && store.entries.isNotEmpty) {
        final last = store.entries.removeLast();
        store.entries.add(last.copyWith(amountMl: last.amountMl + left));
      }
    }

    // Today, in progress: only drinks that have already happened.
    final todayKey = hydrationDayKey(now);
    const today = [(7, 50, 250), (10, 20, 250), (12, 45, 400)];
    for (var i = 0; i < today.length; i++) {
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        today[i].$1,
        today[i].$2,
      );
      if (at.isAfter(now)) continue;
      store.entries.add(
        HydrationEntry(
          id: 'sample_${todayKey}_$i',
          userId: userId,
          amountMl: today[i].$3,
          loggedAt: at,
          dayKey: todayKey,
        ),
      );
    }
    return store;
  }
}
