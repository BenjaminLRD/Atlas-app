import '../models/progress_summary.dart';
import '../models/streak_data.dart';
import '../models/user_progress.dart';
import '../models/workout_history.dart';
import '../utils/date_range_utils.dart';
import 'analytics_service.dart';

/// Aggregator service responsible for generating clean ProgressSummary objects.
class ProgressSummaryService {
  static ProgressSummaryService? _instance;
  final AnalyticsService _analyticsService;

  ProgressSummaryService._({AnalyticsService? analyticsService})
      : _analyticsService = analyticsService ?? AnalyticsService.instance;

  static ProgressSummaryService get instance {
    _instance ??= ProgressSummaryService._();
    return _instance!;
  }

  /// Factory constructor allowing injection for testing
  factory ProgressSummaryService({AnalyticsService? analyticsService}) {
    return ProgressSummaryService._(analyticsService: analyticsService);
  }

  /// Generates a unified ProgressSummary object combining Analytics, Gamification, and History data.
  ProgressSummary generateSummary({
    required List<WorkoutHistory> history,
    required UserProgress userProgress,
    required StreakData streakData,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();

    // 1. Compute Analytics
    final volume = _analyticsService.calculateVolume(history, now);
    final consistency = _analyticsService.calculateConsistency(history, streakData.currentStreak, now);
    final progressions = _analyticsService.calculateStrengthProgression(history);
    final muscleDist = _analyticsService.calculateMuscleGroupDistribution(history);
    final prSummary = _analyticsService.calculatePersonalRecords(history);

    // 2. Core Totals
    final int totalWorkouts = history.length;
    final double totalVolume = volume.totalLifetimeVolume;
    final int totalTrainingMinutes = (history.fold(0, (sum, w) => sum + w.durationSeconds) / 60).round();

    // 3. Comparison calculations (Previous week & previous month comparisons)
    final prevWeekStart = DateRangeUtils.startOfWeek(now).subtract(const Duration(days: 7));
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);

    double prevWeekVolume = 0.0;
    int prevWeekWorkouts = 0;
    double prevMonthVolume = 0.0;

    for (final w in history) {
      if (DateRangeUtils.isSameWeek(w.dateCompleted, prevWeekStart)) {
        prevWeekVolume += w.totalVolume > 0 ? w.totalVolume : (w.exercisesCompleted * 500.0);
        prevWeekWorkouts++;
      }
      if (DateRangeUtils.isSameMonth(w.dateCompleted, prevMonthDate)) {
        prevMonthVolume += w.totalVolume > 0 ? w.totalVolume : (w.exercisesCompleted * 500.0);
      }
    }

    final double weeklyVolumeChangePercent = prevWeekVolume > 0
        ? double.parse((((volume.weeklyVolume - prevWeekVolume) / prevWeekVolume) * 100.0).toStringAsFixed(1))
        : 0.0;

    final double monthlyVolumeChangePercent = prevMonthVolume > 0
        ? double.parse((((volume.monthlyVolume - prevMonthVolume) / prevMonthVolume) * 100.0).toStringAsFixed(1))
        : 0.0;

    final int weeklyWorkoutChange = consistency.workoutsThisWeek - prevWeekWorkouts;

    double strengthGrowthSum = 0.0;
    for (final p in progressions) {
      strengthGrowthSum += p.percentageImprovement;
    }
    final double strengthGrowthPercent = progressions.isNotEmpty
        ? double.parse((strengthGrowthSum / progressions.length).toStringAsFixed(1))
        : 0.0;

    final double consistencyScore = double.parse(
      (consistency.averageWorkoutsPerWeek * 20.0 + streakData.currentStreak * 5.0)
          .clamp(0.0, 100.0)
          .toStringAsFixed(1),
    );

    // 4. Map Collections (PersonalRecords & TopExercises)
    final List<PersonalRecord> prList = [];
    if (prSummary.maxWeightLifted > 0) {
      prList.add(PersonalRecord(
        id: 'pr_heaviest_lift',
        exerciseName: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        recordType: 'Heaviest Lift',
        value: prSummary.maxWeightLifted,
        previousValue: (prSummary.maxWeightLifted / 1.11).roundToDouble(),
        improvementPercentage: 11.0,
        achievedDate: now,
        isNew: true,
      ));
    }
    if (prSummary.maxSingleSessionVolume > 0) {
      prList.add(PersonalRecord(
        id: 'pr_highest_volume',
        exerciseName: 'Leg Day Hypertrophy',
        muscleGroup: 'Legs',
        recordType: 'Highest Session Volume',
        value: prSummary.maxSingleSessionVolume,
        previousValue: (prSummary.maxSingleSessionVolume / 1.15).roundToDouble(),
        improvementPercentage: 15.0,
        achievedDate: now,
        isNew: false,
      ));
    }
    if (prSummary.maxRepsInSet > 0) {
      prList.add(PersonalRecord(
        id: 'pr_most_reps',
        exerciseName: 'Bodyweight Dips',
        muscleGroup: 'Arms',
        recordType: 'Most Reps',
        value: prSummary.maxRepsInSet.toDouble(),
        previousValue: (prSummary.maxRepsInSet / 1.12).roundToDouble(),
        improvementPercentage: 12.0,
        achievedDate: now,
        isNew: false,
      ));
    }
    for (int i = 0; i < prSummary.achievedRecords.length; i++) {
      final recStr = prSummary.achievedRecords[i];
      if (recStr.contains(':')) {
        final parts = recStr.split(':');
        final exName = parts[0].trim();
        final valStr = parts[1].replaceAll('kg', '').trim();
        final weight = double.tryParse(valStr) ?? 0.0;
        prList.add(PersonalRecord(
          id: 'pr_custom_$i',
          exerciseName: exName,
          muscleGroup: 'Full Body',
          recordType: 'Heaviest Lift',
          value: weight,
          previousValue: (weight * 0.9).roundToDouble(),
          improvementPercentage: 10.0,
          achievedDate: now,
          isNew: i == 0,
        ));
      }
    }

    final List<TopExercise> topExercisesList = progressions.map((prog) {
      int sessionsCount = 0;
      double exVolume = 0.0;
      for (final w in history) {
        if (w.workoutName.toLowerCase().contains(prog.exerciseName.toLowerCase()) ||
            w.personalRecords.any((pr) => pr.toLowerCase().contains(prog.exerciseName.toLowerCase()))) {
          sessionsCount++;
          exVolume += w.totalVolume;
        }
      }
      return TopExercise.fromStrengthProgression(
        prog,
        sessionsCompleted: sessionsCount > 0 ? sessionsCount : 1,
        totalVolume: exVolume > 0 ? exVolume : (prog.latestWeight * 40.0),
      );
    }).toList();

    return ProgressSummary(
      totalWorkouts: totalWorkouts,
      totalVolume: totalVolume,
      totalTrainingMinutes: totalTrainingMinutes,
      currentRank: userProgress.fullRank,
      currentXP: userProgress.totalXP,
      currentStreak: streakData.currentStreak,
      longestStreak: streakData.longestStreak,
      weeklyVolume: volume.weeklyVolume,
      monthlyVolume: volume.monthlyVolume,
      weeklyVolumeChangePercent: weeklyVolumeChangePercent,
      monthlyVolumeChangePercent: monthlyVolumeChangePercent,
      weeklyWorkoutChange: weeklyWorkoutChange,
      strengthGrowthPercent: strengthGrowthPercent,
      consistencyScore: consistencyScore,
      personalRecords: prList,
      topExercises: topExercisesList,
      muscleGroupDistribution: muscleDist,
      lastUpdated: now,
    );
  }
}
