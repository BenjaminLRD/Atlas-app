import 'sample_world.dart';

/// Timeframes the sample data supports. There are no monthly figures, so
/// there is no month option.
enum SampleTimeframe {
  week('This week'),
  allTime('All time');

  final String label;
  const SampleTimeframe(this.label);
}

/// Ranking categories, each with the timeframes the scripted data covers.
enum SampleCategory {
  workouts('Workouts', {SampleTimeframe.week, SampleTimeframe.allTime}),
  minutes('Minutes', {SampleTimeframe.week}),
  steps('Steps', {SampleTimeframe.week}),
  streak('Streak', {SampleTimeframe.week}),
  volume('Volume', {SampleTimeframe.allTime}),
  challenges('Challenges', {SampleTimeframe.allTime});

  final String label;
  final Set<SampleTimeframe> timeframes;
  const SampleCategory(this.label, this.timeframes);
}

class SampleRankRow {
  final int rank;
  final SampleAthlete athlete;
  final num value;
  final String valueLabel;
  const SampleRankRow(this.rank, this.athlete, this.value, this.valueLabel);
}

/// Demo leaderboard built only from the scripted stats of the 11 sample
/// athletes. It never includes real users, and nothing here is a measurement.
class SampleLeaderboard {
  const SampleLeaderboard._();

  static List<SampleCategory> categoriesFor(SampleTimeframe t) => [
    for (final c in SampleCategory.values)
      if (c.timeframes.contains(t)) c,
  ];

  static num _value(SampleAthlete a, SampleCategory c, SampleTimeframe t) {
    final s = a.stats;
    switch (c) {
      case SampleCategory.workouts:
        return t == SampleTimeframe.week ? s.weeklyWorkouts : s.totalWorkouts;
      case SampleCategory.minutes:
        return s.weeklyMinutes;
      case SampleCategory.steps:
        return s.avgDailySteps;
      case SampleCategory.streak:
        return s.streakDays;
      case SampleCategory.volume:
        return s.totalVolumeKg;
      case SampleCategory.challenges:
        return s.challengesCompleted;
    }
  }

  static String _label(num v, SampleCategory c) {
    String grouped(num n) {
      final s = n.round().toString();
      final b = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
        b.write(s[i]);
      }
      return b.toString();
    }

    switch (c) {
      case SampleCategory.workouts:
        return grouped(v);
      case SampleCategory.minutes:
        return '${grouped(v)} min';
      case SampleCategory.steps:
        return '${grouped(v)} / day';
      case SampleCategory.streak:
        return '${grouped(v)} days';
      case SampleCategory.volume:
        return '${grouped(v)} kg';
      case SampleCategory.challenges:
        return grouped(v);
    }
  }

  /// Ranked rows for [category] in [timeframe]. Equal values keep a stable
  /// order by name; ranks are 1..n.
  static List<SampleRankRow> rank(
    SampleCategory category,
    SampleTimeframe timeframe,
  ) {
    assert(category.timeframes.contains(timeframe));
    final entries =
        [
          for (final a in SampleWorld.athletes)
            (a, _value(a, category, timeframe)),
        ]..sort((x, y) {
          final byValue = y.$2.compareTo(x.$2);
          return byValue != 0 ? byValue : x.$1.name.compareTo(y.$1.name);
        });
    return [
      for (var i = 0; i < entries.length; i++)
        SampleRankRow(
          i + 1,
          entries[i].$1,
          entries[i].$2,
          _label(entries[i].$2, category),
        ),
    ];
  }
}
