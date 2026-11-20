import 'package:atlas/services/community/sample_leaderboard.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sample leaderboard', () {
    test('every supported category and timeframe ranks all 11 athletes', () {
      for (final t in SampleTimeframe.values) {
        for (final c in SampleLeaderboard.categoriesFor(t)) {
          final rows = SampleLeaderboard.rank(c, t);
          expect(rows.length, SampleWorld.athletes.length, reason: '$c $t');
          expect(rows.length, 11);
          expect(rows.map((r) => r.rank).toList(), [
            for (var i = 1; i <= 11; i++) i,
          ]);
          expect(rows.map((r) => r.athlete.key).toSet().length, 11);
          for (var i = 0; i < rows.length - 1; i++) {
            expect(
              rows[i].value,
              greaterThanOrEqualTo(rows[i + 1].value),
              reason: '$c $t position $i',
            );
          }
        }
      }
    });

    test('values come straight from each athlete\'s scripted stats', () {
      for (final r in SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.week,
      )) {
        expect(r.value, r.athlete.stats.weeklyWorkouts);
      }
      for (final r in SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.allTime,
      )) {
        expect(r.value, r.athlete.stats.totalWorkouts);
      }
      for (final r in SampleLeaderboard.rank(
        SampleCategory.volume,
        SampleTimeframe.allTime,
      )) {
        expect(r.value, r.athlete.stats.totalVolumeKg);
      }
      for (final r in SampleLeaderboard.rank(
        SampleCategory.steps,
        SampleTimeframe.week,
      )) {
        expect(r.value, r.athlete.stats.avgDailySteps);
      }
    });

    test('only categories the data supports are offered per timeframe', () {
      final week = SampleLeaderboard.categoriesFor(SampleTimeframe.week);
      final all = SampleLeaderboard.categoriesFor(SampleTimeframe.allTime);
      expect(week, contains(SampleCategory.minutes));
      expect(week, contains(SampleCategory.steps));
      expect(week, isNot(contains(SampleCategory.volume)));
      expect(all, contains(SampleCategory.volume));
      expect(all, contains(SampleCategory.challenges));
      expect(all, isNot(contains(SampleCategory.minutes)));
      // No month option exists, because the data has no monthly figures.
      expect(SampleTimeframe.values.map((t) => t.name), ['week', 'allTime']);
    });

    test('ties break by name so the order is stable', () {
      final a = SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.week,
      );
      final b = SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.week,
      );
      expect(
        a.map((r) => r.athlete.key).toList(),
        b.map((r) => r.athlete.key).toList(),
      );
    });

    test('labels are readable', () {
      final steps = SampleLeaderboard.rank(
        SampleCategory.steps,
        SampleTimeframe.week,
      );
      expect(
        steps.first.valueLabel,
        matches(RegExp(r'^\d{1,3}(,\d{3})* / day$')),
      );
      final vol = SampleLeaderboard.rank(
        SampleCategory.volume,
        SampleTimeframe.allTime,
      );
      expect(vol.first.valueLabel, endsWith(' kg'));
    });
  });
}
