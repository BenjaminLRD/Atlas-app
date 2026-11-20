import '../../models/daily_nutrition.dart';
import '../../models/health_metric.dart';
import '../../models/recovery_summary.dart';
import '../../models/weekly_coach_review.dart';
import '../../models/workout_history.dart';
import '../nutrition/weekly_nutrition_stats.dart';

/// Generates autonomous 7-day retrospective coaching reviews.
class WeeklyCoachReviewService {
  static WeeklyCoachReviewService? _instance;
  static WeeklyCoachReviewService get instance =>
      _instance ??= WeeklyCoachReviewService();

  /// Compiles multi-domain athlete data across the last 7 days into a [WeeklyCoachReview].
  WeeklyCoachReview generateReview({
    required List<WorkoutHistory> workoutHistory,
    required List<DailyNutrition> nutritionHistory,
    required List<HealthMetric> healthMetrics,
    required RecoverySummary currentRecovery,
    double? currentWeight,
    double? previousWeight,
  }) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    // 1. Filter Last 7 Days Workouts
    final last7DaysWorkouts = workoutHistory
        .where((w) => w.dateCompleted.isAfter(sevenDaysAgo))
        .toList();
    final prior7DaysWorkouts = workoutHistory
        .where(
          (w) =>
              w.dateCompleted.isAfter(fourteenDaysAgo) &&
              w.dateCompleted.isBefore(sevenDaysAgo),
        )
        .toList();

    final workoutsCompleted = last7DaysWorkouts.length;
    final currentVolume = last7DaysWorkouts.fold<double>(
      0.0,
      (acc, w) => acc + w.totalVolume,
    );
    final priorVolume = prior7DaysWorkouts.fold<double>(
      0.0,
      (acc, w) => acc + w.totalVolume,
    );

    double volumeChangePct = 0.0;
    if (priorVolume > 0) {
      volumeChangePct = ((currentVolume - priorVolume) / priorVolume) * 100.0;
    } else if (currentVolume > 0) {
      volumeChangePct = 100.0;
    }

    // Identify Weak Areas / Splits
    final muscleGroupsHit = <String>{};
    for (final w in last7DaysWorkouts) {
      muscleGroupsHit.add(w.workoutName);
    }

    final weakAreas = <String>[];
    if (!muscleGroupsHit.any(
      (s) =>
          s.toLowerCase().contains('leg') || s.toLowerCase().contains('squat'),
    )) {
      weakAreas.add('Lower Body / Legs volume');
    }
    if (!muscleGroupsHit.any(
      (s) =>
          s.toLowerCase().contains('pull') || s.toLowerCase().contains('back'),
    )) {
      weakAreas.add('Posterior Chain / Back volume');
    }

    // 2. Nutrition Consistency (Last 7 Days)
    final recentNutrition = nutritionHistory.where((n) {
      final parsedDate = DateTime.tryParse(n.date);
      return parsedDate != null && parsedDate.isAfter(sevenDaysAgo);
    }).toList();

    // Days with foods that lack a calorie or protein value are left out of
    // the average and the rate, never counted as zero. The figures read 0
    // when no day is complete (as with no logs), and the summary says why.
    final stats = WeeklyNutritionStats.from(recentNutrition);
    final avgDailyCalories = stats.averageCalories ?? 0.0;
    final proteinConsistency = stats.proteinHitPercent ?? 0.0;

    // 3. Recovery & Sleep
    final recentHealth = healthMetrics
        .where((h) => h.timestamp.isAfter(sevenDaysAgo))
        .toList();
    double totalSleepHours = 0.0;
    int sleepSamples = 0;

    for (final h in recentHealth) {
      if (h.sleepMinutes != null && h.sleepMinutes! > 0) {
        totalSleepHours += h.sleepHours;
        sleepSamples++;
      }
    }

    final avgSleepHours = sleepSamples > 0
        ? (totalSleepHours / sleepSamples)
        : 7.4;
    final avgReadiness = currentRecovery.score > 0 ? currentRecovery.score : 82;

    // 4. Weight Trend
    double weightChange = 0.0;
    if (currentWeight != null && previousWeight != null) {
      weightChange = currentWeight - previousWeight;
    }

    // 5. Synthesize Narrative & Action Items
    String strengthSummary;
    if (workoutsCompleted >= 3) {
      strengthSummary =
          'Strong training week with $workoutsCompleted workouts completed and ${volumeChangePct >= 0 ? '+' : ''}${volumeChangePct.toStringAsFixed(1)}% volume progression.';
    } else if (workoutsCompleted > 0) {
      strengthSummary =
          'Completed $workoutsCompleted workout${workoutsCompleted > 1 ? 's' : ''}. Aim to reach 3-4 sessions next week for optimal stimulus.';
    } else {
      strengthSummary = 'No workouts logged in the last 7 days.';
    }

    String nutritionSummary;
    if (recentNutrition.isNotEmpty) {
      if (stats.averageCalories != null && stats.proteinHitPercent != null) {
        nutritionSummary =
            'Daily calories averaged ${avgDailyCalories.toInt()} kcal with protein target achieved on ${proteinConsistency.toInt()}% of days.';
      } else {
        final calorieText = stats.averageCalories == null
            ? 'Daily calories could not be averaged because foods have no calorie value'
            : 'Daily calories averaged ${avgDailyCalories.toInt()} kcal';
        final proteinText = stats.proteinHitPercent == null
            ? 'the protein target cannot be checked because foods have no protein value'
            : 'protein target achieved on ${proteinConsistency.toInt()}% of days';
        nutritionSummary = '$calorieText, and $proteinText.';
      }
      final note = stats.excludedNote;
      if (note != null) nutritionSummary = '$nutritionSummary $note';
    } else {
      nutritionSummary =
          'Track daily meals to unlock nutrition trend intelligence.';
    }

    String primaryRec;
    final actionItems = <String>[];

    if (weakAreas.isNotEmpty) {
      primaryRec =
          'Increase training frequency for ${weakAreas.join(' and ')}.';
      actionItems.add('Schedule a dedicated ${weakAreas.first} session.');
    } else if (volumeChangePct > 15.0) {
      primaryRec =
          'High volume surge detected. Prioritize recovery and restful sleep.';
      actionItems.add('Ensure 8 hours of sleep and adequate hydration.');
    } else {
      primaryRec =
          'Maintain progressive overload and consistent protein distribution.';
      actionItems.add('Hit daily protein target of 150g+ consistently.');
    }

    if (stats.proteinHitPercent != null && proteinConsistency < 70.0) {
      actionItems.add(
        'Increase protein pacing with high-protein breakfast and snacks.',
      );
    }

    return WeeklyCoachReview(
      weekStartDate: sevenDaysAgo,
      weekEndDate: now,
      workoutsCompleted: workoutsCompleted,
      volumeChangePercentage: double.parse(volumeChangePct.toStringAsFixed(1)),
      personalRecordsAchieved: const [],
      weakAreasIdentified: weakAreas,
      averageDailyCalories: double.parse(avgDailyCalories.toStringAsFixed(0)),
      proteinConsistencyPercentage: double.parse(
        proteinConsistency.toStringAsFixed(1),
      ),
      averageSleepHours: double.parse(avgSleepHours.toStringAsFixed(1)),
      averageReadinessScore: avgReadiness,
      weightChangeKg: double.parse(weightChange.toStringAsFixed(1)),
      strengthSummary: strengthSummary,
      nutritionSummary: nutritionSummary,
      primaryRecommendation: primaryRec,
      actionItems: actionItems.isNotEmpty
          ? actionItems
          : ['Maintain workout routine'],
    );
  }
}
