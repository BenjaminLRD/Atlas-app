import '../../models/workout_history.dart';

/// Evaluates acute vs chronic training workloads, workload ratios (ACWR),
/// Training Stress Balance (TSB), and detects overtraining / volume spikes.
class TrainingLoadEngine {
  const TrainingLoadEngine();

  /// Calculates Acute Training Load (ATL) - Cumulative workload over the last 7 days.
  double calculateAcuteTrainingLoad(
    List<WorkoutHistory> workouts, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentWorkouts = workouts.where((w) {
      return w.dateCompleted.isAfter(sevenDaysAgo) &&
          w.dateCompleted.isBefore(now.add(const Duration(hours: 1)));
    }).toList();

    if (recentWorkouts.isEmpty) return 0.0;

    double totalLoad = 0.0;
    for (final workout in recentWorkouts) {
      totalLoad += _calculateSessionWorkload(workout);
    }

    return double.parse(totalLoad.toStringAsFixed(1));
  }

  /// Calculates Chronic Training Load (CTL) - Weekly average workload over the last 28 days.
  double calculateChronicTrainingLoad(
    List<WorkoutHistory> workouts, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final twentyEightDaysAgo = now.subtract(const Duration(days: 28));

    final pastWorkouts = workouts.where((w) {
      return w.dateCompleted.isAfter(twentyEightDaysAgo) &&
          w.dateCompleted.isBefore(now.add(const Duration(hours: 1)));
    }).toList();

    if (pastWorkouts.isEmpty) return 0.0;

    double total28DayLoad = 0.0;
    for (final workout in pastWorkouts) {
      total28DayLoad += _calculateSessionWorkload(workout);
    }

    // Normalize 28-day sum to a 7-day rolling average (divided by 4 weeks)
    final weeklyAverageCTL = total28DayLoad / 4.0;
    return double.parse(weeklyAverageCTL.toStringAsFixed(1));
  }

  /// Computes Acute:Chronic Workload Ratio (ACWR).
  /// Sweet spot for athletic progression: 0.8 - 1.3.
  /// Volume spike threshold: > 1.5 (elevated injury risk).
  double calculateACWR({
    required double acuteLoad,
    required double chronicLoad,
  }) {
    if (chronicLoad <= 0.0) {
      return acuteLoad > 0 ? 1.5 : 1.0;
    }
    final ratio = acuteLoad / chronicLoad;
    return double.parse(ratio.toStringAsFixed(2));
  }

  /// Computes Training Stress Balance (TSB) = Chronic Training Load - Acute Training Load.
  /// Positive = Freshness / Recovery; Negative = Fatigue.
  double calculateTSB({
    required double acuteLoad,
    required double chronicLoad,
  }) {
    final tsb = chronicLoad - acuteLoad;
    return double.parse(tsb.toStringAsFixed(1));
  }

  /// Detects whether the athlete underwent a dangerous sudden volume spike (> 1.5 ACWR).
  bool isVolumeSpike(double acwr) {
    return acwr > 1.50;
  }

  /// Evaluates overtraining risk based on ACWR, TSB, and training frequency.
  bool evaluateOvertrainingRisk({
    required double acwr,
    required double tsb,
    required int workoutsLast7Days,
  }) {
    // Risk triggers: extreme volume spike OR severe chronic fatigue + high frequency
    if (acwr > 1.55) return true;
    if (tsb < -400.0 && workoutsLast7Days >= 5) return true;
    return false;
  }

  /// Calculates individual workout session workload using tonnage or RPE duration.
  double _calculateSessionWorkload(WorkoutHistory workout) {
    // 1. If total tonnage (volume) is recorded
    if (workout.totalVolume > 0) {
      return workout.totalVolume;
    }

    // 2. Fallback: estimate from duration and intensity rating
    final durationMins = workout.durationSeconds > 0 ? (workout.durationSeconds / 60.0).round() : 45;
    final rpe = workout.intensityScore ?? 7.0; // 1-10 scale
    return durationMins * rpe * 10.0;
  }
}
