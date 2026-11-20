import '../../models/health_metric.dart';
import '../../models/workout_history.dart';

/// Detailed breakdown result of the athlete's 4-pillar recovery calculation.
///
/// A pillar without data is null and is left out; the total is scaled to the
/// pillars that are known. Sleep is the physiological pillar: without a
/// recorded night there is no recovery score at all ([isAvailable] is false).
class RecoveryBreakdown {
  /// 0 - 100, or null when there is not enough real data.
  final int? totalScore;
  final double? sleepComponent; // Max 40
  final double? trainingComponent; // Max 30
  final double? activityComponent; // Max 20
  final double? restDaysComponent; // Max 10
  final String statusEmoji;
  final String statusText;
  final String recommendation;

  const RecoveryBreakdown({
    required this.totalScore,
    required this.sleepComponent,
    required this.trainingComponent,
    required this.activityComponent,
    required this.restDaysComponent,
    required this.statusEmoji,
    required this.statusText,
    required this.recommendation,
  });

  /// No recovery score could be made from recorded data.
  factory RecoveryBreakdown.unavailable({
    double? trainingComponent,
    double? activityComponent,
    double? restDaysComponent,
  }) => RecoveryBreakdown(
    totalScore: null,
    sleepComponent: null,
    trainingComponent: trainingComponent,
    activityComponent: activityComponent,
    restDaysComponent: restDaysComponent,
    statusEmoji: '',
    statusText: 'Recovery unavailable',
    recommendation:
        'Record sleep (from a watch, Health Connect or a manual entry) to get a recovery score.',
  );

  bool get isAvailable => totalScore != null;

  /// Short headline badge (e.g. "82/100 • Ready for heavy training 🔥")
  String get formattedSummary =>
      isAvailable ? '$totalScore/100 • $statusText $statusEmoji' : statusText;

  /// Whether the user should deload or reduce volume (never on no data).
  bool get shouldReduceVolume => totalScore != null && totalScore! < 60;
}

/// Recovery Score Engine calculating daily athlete readiness
/// based on Sleep (40%), Training Load (30%), Activity (20%), and Rest Days (10%).
class RecoveryService {
  static final RecoveryService _instance = RecoveryService._internal();
  static RecoveryService get instance => _instance;

  RecoveryService._internal();

  /// Consecutive days with a workout, counting back from today (or from
  /// yesterday when today has none yet). Null when there is no workout
  /// history: that is "unknown", not zero days.
  static int? consecutiveTrainingDays(
    List<WorkoutHistory> workouts,
    DateTime now,
  ) {
    if (workouts.isEmpty) return null;
    final days = {
      for (final w in workouts)
        DateTime(
          w.dateCompleted.year,
          w.dateCompleted.month,
          w.dateCompleted.day,
        ),
    };
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Days without a workout in the last 7. Null with no workout history.
  static int? restDaysLast7(List<WorkoutHistory> workouts, DateTime now) {
    if (workouts.isEmpty) return null;
    final today = DateTime(now.year, now.month, now.day);
    final trained = <DateTime>{};
    for (final w in workouts) {
      final d = DateTime(
        w.dateCompleted.year,
        w.dateCompleted.month,
        w.dateCompleted.day,
      );
      final age = today.difference(d).inDays;
      if (age >= 0 && age < 7) trained.add(d);
    }
    return 7 - trained.length;
  }

  /// Calculates composite recovery readiness score from the inputs that are
  /// recorded. A null input is unknown: its pillar is skipped. Without a sleep
  /// reading the result is unavailable.
  RecoveryBreakdown calculateRecovery({
    int? sleepMinutes,
    int? consecutiveTrainingDays,
    int? stepsToday,
    int? restDaysLast7Days,
    double recentVolumeSurgePercent = 0.0, // e.g. 30.0 for 30% volume spike
  }) {
    // 2. Training Load Component (30% Weight)
    // Evaluates consecutive training days and recent volume surges
    double? trainingScore;
    if (consecutiveTrainingDays != null) {
      var s = 30.0;
      if (consecutiveTrainingDays >= 5) {
        s -= 12.0;
      } else if (consecutiveTrainingDays >= 4) {
        s -= 7.0;
      } else if (consecutiveTrainingDays >= 3) {
        s -= 3.0;
      }

      if (recentVolumeSurgePercent > 25.0) {
        s -= 6.0;
      } else if (recentVolumeSurgePercent > 15.0) {
        s -= 3.0;
      }
      trainingScore = s.clamp(5.0, 30.0);
    }

    // 3. Activity / Movement Component (20% Weight)
    // Optimal daily NEAT movement is 7,000 - 11,000 steps
    double? activityScore;
    if (stepsToday != null) {
      if (stepsToday >= 7000 && stepsToday <= 12000) {
        activityScore = 20.0;
      } else if (stepsToday >= 5000 && stepsToday < 7000) {
        activityScore = 17.0;
      } else if (stepsToday > 12000) {
        // Very high steps adds mild fatigue
        activityScore = 16.0;
      } else {
        activityScore = 12.0;
      }
    }

    // 4. Rest Days Component (10% Weight)
    // 1-2 rest days in 7 days is optimal
    double? restScore;
    if (restDaysLast7Days != null) {
      if (restDaysLast7Days >= 1 && restDaysLast7Days <= 3) {
        restScore = 10.0;
      } else if (restDaysLast7Days == 0) {
        restScore = 4.0;
      } else {
        // 4+ rest days
        restScore = 8.0;
      }
    }

    // 1. Sleep Component (40% Weight): the physiological pillar.
    // Target is 8 hours (480 mins). 7h 20m (440m) yields ~36.7 / 40.
    if (sleepMinutes == null || sleepMinutes <= 0) {
      return RecoveryBreakdown.unavailable(
        trainingComponent: trainingScore,
        activityComponent: activityScore,
        restDaysComponent: restScore,
      );
    }
    double sleepScore;
    if (sleepMinutes >= 480) {
      sleepScore = 40.0;
    } else if (sleepMinutes >= 420) {
      // 7h - 8h
      sleepScore = 35.0 + ((sleepMinutes - 420) / 60.0) * 5.0;
    } else if (sleepMinutes >= 360) {
      // 6h - 7h
      sleepScore = 26.0 + ((sleepMinutes - 360) / 60.0) * 9.0;
    } else {
      // < 6h
      sleepScore = (sleepMinutes / 360.0) * 26.0;
    }
    sleepScore = sleepScore.clamp(0.0, 40.0);

    // Composite from the known pillars, scaled to 0 - 100.
    var earned = sleepScore;
    var possible = 40.0;
    if (trainingScore != null) {
      earned += trainingScore;
      possible += 30.0;
    }
    if (activityScore != null) {
      earned += activityScore;
      possible += 20.0;
    }
    if (restScore != null) {
      earned += restScore;
      possible += 10.0;
    }
    final total = (earned / possible * 100).round().clamp(0, 100);

    String statusEmoji;
    String statusText;
    String recommendation;

    if (total >= 80) {
      statusEmoji = '🔥';
      statusText = 'Ready for heavy training';
      recommendation =
          'Your central nervous system and muscles are primed. Push progressive overload today!';
    } else if (total >= 60) {
      statusEmoji = '👍';
      statusText = 'Good recovery';
      recommendation =
          'Solid readiness. Proceed with standard scheduled workout volume and intensity.';
    } else if (total >= 40) {
      statusEmoji = '⚠️';
      statusText = 'Moderate fatigue';
      recommendation =
          'Slight accumulated fatigue. Consider reducing working set volume by 15-20%.';
    } else {
      statusEmoji = '🛑';
      statusText = 'High fatigue / Rest recommended';
      recommendation =
          'Sleep or systemic fatigue is high. Prioritize mobility, hydration, and active recovery.';
    }

    return RecoveryBreakdown(
      totalScore: total,
      sleepComponent: sleepScore,
      trainingComponent: trainingScore,
      activityComponent: activityScore,
      restDaysComponent: restScore,
      statusEmoji: statusEmoji,
      statusText: statusText,
      recommendation: recommendation,
    );
  }

  /// Convenience helper directly from a [HealthMetric].
  ///
  /// [stepsToday] is today's total from the step service (null with no
  /// reading); the metric's own step count is not used so every screen and
  /// calculation shares one daily total. [workouts] gives the training and
  /// rest-day pillars; without it (or with no history) they are skipped.
  RecoveryBreakdown calculateFromHealthMetric(
    HealthMetric metric, {
    int? stepsToday,
    List<WorkoutHistory>? workouts,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final sleep = metric.sleepMinutes;
    return calculateRecovery(
      sleepMinutes: (sleep != null && sleep > 0) ? sleep : null,
      consecutiveTrainingDays: workouts == null
          ? null
          : consecutiveTrainingDays(workouts, at),
      stepsToday: stepsToday,
      restDaysLast7Days: workouts == null ? null : restDaysLast7(workouts, at),
    );
  }
}
