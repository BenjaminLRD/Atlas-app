/// Daily record of the athlete's 6 core micro-habits.
class DailyHabitEntry {
  final DateTime date;
  final double sleepHours;
  final double proteinGrams;
  final double targetProteinGrams;
  final double waterLiters;
  final double targetWaterLiters;
  final int stepCount;
  final int targetSteps;
  final int mobilityMinutes;
  final bool workoutCompleted;

  const DailyHabitEntry({
    required this.date,
    required this.sleepHours,
    required this.proteinGrams,
    this.targetProteinGrams = 160.0,
    required this.waterLiters,
    this.targetWaterLiters = 3.0,
    required this.stepCount,
    this.targetSteps = 8000,
    required this.mobilityMinutes,
    required this.workoutCompleted,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'sleep_hours': sleepHours,
    'protein_g': proteinGrams,
    'water_l': waterLiters,
    'step_count': stepCount,
    'mobility_min': mobilityMinutes,
    'workout_completed': workoutCompleted,
  };
}

/// Evaluation summary of habit execution and daily readiness.
class HabitScoreSummary {
  final double overallHabitScore; // 0.0 to 100.0
  final int currentStreakDays;
  final String topPerformingHabit;
  final String laggingHabit;
  final int dailyReadinessIndex; // 0 to 100

  const HabitScoreSummary({
    required this.overallHabitScore,
    required this.currentStreakDays,
    required this.topPerformingHabit,
    required this.laggingHabit,
    required this.dailyReadinessIndex,
  });

  Map<String, dynamic> toJson() => {
    'habit_score': overallHabitScore,
    'streak_days': currentStreakDays,
    'top_habit': topPerformingHabit,
    'lagging_habit': laggingHabit,
    'readiness_index': dailyReadinessIndex,
  };
}

/// Habit Intelligence & Micro-Habit Tracking Engine.
/// Tracks sleep, protein, hydration, steps, mobility, and workout consistency to forecast daily readiness.
class HabitTrackingEngine {
  static HabitTrackingEngine? _instance;
  static HabitTrackingEngine get instance =>
      _instance ??= HabitTrackingEngine();

  static void resetInstance() {
    _instance = null;
  }

  final List<DailyHabitEntry> _habitLogs = [];

  List<DailyHabitEntry> get habitLogs => List.unmodifiable(_habitLogs);

  /// Records daily habit execution and computes the evaluation summary.
  HabitScoreSummary recordDailyHabits(DailyHabitEntry entry) {
    _habitLogs.add(entry);

    // 1. Calculate Individual Habit Scores
    final sleepScore = ((entry.sleepHours / 7.5) * 100.0).clamp(0.0, 100.0);
    final proteinScore = ((entry.proteinGrams / entry.targetProteinGrams) * 100.0).clamp(0.0, 100.0);
    final waterScore = ((entry.waterLiters / entry.targetWaterLiters) * 100.0).clamp(0.0, 100.0);
    final stepScore = ((entry.stepCount / entry.targetSteps) * 100.0).clamp(0.0, 100.0);
    final mobilityScore = (entry.mobilityMinutes >= 15 ? 100.0 : (entry.mobilityMinutes / 15.0) * 100.0);
    final workoutScore = entry.workoutCompleted ? 100.0 : 70.0;

    // Weighted Overall Score
    final overall = (sleepScore * 0.25) +
        (proteinScore * 0.25) +
        (waterScore * 0.15) +
        (stepScore * 0.15) +
        (mobilityScore * 0.10) +
        (workoutScore * 0.10);

    // Calculate Streak
    int streak = 1;
    for (int i = _habitLogs.length - 2; i >= 0; i--) {
      final prev = _habitLogs[i];
      if (prev.sleepHours >= 6.5 && prev.proteinGrams >= (prev.targetProteinGrams * 0.85)) {
        streak++;
      } else {
        break;
      }
    }

    final readiness = (overall * 0.90 + (streak * 2.0)).clamp(40.0, 100.0).round();

    return HabitScoreSummary(
      overallHabitScore: double.parse(overall.toStringAsFixed(1)),
      currentStreakDays: streak,
      topPerformingHabit: proteinScore >= 95 ? 'Protein Target Adherence' : 'Sleep Duration',
      laggingHabit: waterScore < 80 ? 'Hydration' : 'Daily Mobility',
      dailyReadinessIndex: readiness,
    );
  }
}
