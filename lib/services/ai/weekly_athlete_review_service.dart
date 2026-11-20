import '../../models/daily_nutrition.dart';
import '../../models/health_metric.dart';
import '../../models/recovery_summary.dart';
import '../../models/workout_history.dart';
import '../nutrition/weekly_nutrition_stats.dart';

/// Comprehensive 7-day retrospective athletic performance report.
class WeeklyAthleteReport {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String grade; // 'A+', 'A', 'B+', 'B', 'C', 'D'
  final int workoutsCompleted;
  final int workoutsTarget;
  final double volumeProgressionPercentage;
  final double totalVolumeKg;
  final List<String> personalRecords;
  final double consistencyPercentage;
  final int averageDailyCalories;
  final double proteinAdherencePercentage;
  final double averageSleepHours;
  final int averageReadinessScore;
  final double weightDeltaKg;
  final List<String> strengths;
  final List<String> growthAreas;
  final String nextWeekFocus;
  final List<String> actionItems;
  final String summaryText;

  const WeeklyAthleteReport({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.grade,
    required this.workoutsCompleted,
    this.workoutsTarget = 4,
    required this.volumeProgressionPercentage,
    required this.totalVolumeKg,
    this.personalRecords = const [],
    required this.consistencyPercentage,
    required this.averageDailyCalories,
    required this.proteinAdherencePercentage,
    required this.averageSleepHours,
    required this.averageReadinessScore,
    this.weightDeltaKg = 0.0,
    this.strengths = const [],
    this.growthAreas = const [],
    required this.nextWeekFocus,
    this.actionItems = const [],
    required this.summaryText,
  });

  Map<String, dynamic> toJson() => {
    'week_start_date': weekStartDate.toIso8601String(),
    'week_end_date': weekEndDate.toIso8601String(),
    'grade': grade,
    'workouts_completed': workoutsCompleted,
    'workouts_target': workoutsTarget,
    'volume_progression_percentage': volumeProgressionPercentage,
    'total_volume_kg': totalVolumeKg,
    'personal_records': personalRecords,
    'consistency_percentage': consistencyPercentage,
    'average_daily_calories': averageDailyCalories,
    'protein_adherence_percentage': proteinAdherencePercentage,
    'average_sleep_hours': averageSleepHours,
    'average_readiness_score': averageReadinessScore,
    'weight_delta_kg': weightDeltaKg,
    'strengths': strengths,
    'growth_areas': growthAreas,
    'next_week_focus': nextWeekFocus,
    'action_items': actionItems,
    'summary_text': summaryText,
  };
}

/// Autonomous Weekly AI Review service synthesizing 7-day trailing telemetry across
/// strength progression, training consistency, nutrition adherence, recovery, and milestones.
class WeeklyAthleteReviewService {
  static WeeklyAthleteReviewService? _instance;
  static WeeklyAthleteReviewService get instance =>
      _instance ??= WeeklyAthleteReviewService();

  /// Compiles multi-domain athlete data across the trailing 7 days into a [WeeklyAthleteReport].
  WeeklyAthleteReport generateReport({
    required String userId,
    List<WorkoutHistory> workoutHistory = const [],
    List<DailyNutrition> nutritionHistory = const [],
    List<HealthMetric> healthMetrics = const [],
    RecoverySummary? currentRecovery,
    double? currentWeight,
    double? previousWeight,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    // -------------------------------------------------------------------------
    // 1. STRENGTH PROGRESSION & WORKOUT CONSISTENCY
    // -------------------------------------------------------------------------
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
    const workoutsTarget = 4;
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

    final consistencyPct = ((workoutsCompleted / workoutsTarget) * 100.0).clamp(
      0.0,
      100.0,
    );

    // Identify PRs achieved
    final prs = <String>[];
    for (final w in last7DaysWorkouts) {
      if (w.completionPercentage >= 100 && w.totalVolume > 2500) {
        prs.add('${w.workoutName} Volume Benchmark');
      }
    }

    // -------------------------------------------------------------------------
    // 2. NUTRITION ADHERENCE
    // -------------------------------------------------------------------------
    final recentNutrition = nutritionHistory.where((n) {
      final parsed = DateTime.tryParse(n.date);
      return parsed != null && parsed.isAfter(sevenDaysAgo);
    }).toList();

    // No logged days means no figures, not an assumed healthy week. Days
    // with foods that lack a calorie or protein value are left out of the
    // average and the rate instead of counting as zero.
    final stats = WeeklyNutritionStats.from(recentNutrition);
    final avgCalories = (stats.averageCalories ?? 0.0).round();
    final proteinKnown = stats.proteinHitPercent != null;
    final proteinAdherence = stats.proteinHitPercent ?? 0.0;

    // -------------------------------------------------------------------------
    // 3. RECOVERY & SLEEP TELEMETRY
    // -------------------------------------------------------------------------
    final recentHealth = healthMetrics
        .where((h) => h.timestamp.isAfter(sevenDaysAgo))
        .toList();
    double totalSleep = 0.0;
    int sleepSamples = 0;

    for (final h in recentHealth) {
      if (h.sleepMinutes != null && h.sleepMinutes! > 0) {
        totalSleep += h.sleepHours;
        sleepSamples++;
      }
    }

    final avgSleep = sleepSamples > 0 ? (totalSleep / sleepSamples) : 7.5;
    final avgReadiness = currentRecovery?.score ?? 82;

    // -------------------------------------------------------------------------
    // 4. WEIGHT TREND
    // -------------------------------------------------------------------------
    double weightChange = 0.0;
    if (currentWeight != null && previousWeight != null) {
      weightChange = currentWeight - previousWeight;
    }

    // -------------------------------------------------------------------------
    // 5. SYNTHESIS: STRENGTHS, GROWTH AREAS & LETTER GRADE
    // -------------------------------------------------------------------------
    final strengths = <String>[];
    final growthAreas = <String>[];
    final actionItems = <String>[];

    if (workoutsCompleted >= 4) {
      strengths.add(
        'Hit or exceeded weekly training frequency ($workoutsCompleted sessions).',
      );
    } else {
      growthAreas.add(
        'Completed $workoutsCompleted/$workoutsTarget scheduled sessions.',
      );
      actionItems.add(
        'Schedule specific calendar blocks for training days next week.',
      );
    }

    if (volumeChangePct >= 0) {
      strengths.add(
        'Positive volume progression (${volumeChangePct >= 0 ? '+' : ''}${volumeChangePct.toStringAsFixed(1)}% vs prior week).',
      );
    } else {
      growthAreas.add(
        'Training volume dropped by ${volumeChangePct.abs().toStringAsFixed(1)}%.',
      );
    }

    if (!proteinKnown && recentNutrition.isNotEmpty) {
      // No claim either way: every logged day has foods without protein.
      growthAreas.add(
        'Protein could not be checked: logged foods have no protein value.',
      );
    } else if (proteinAdherence >= 80.0) {
      strengths.add(
        'High protein consistency (${proteinAdherence.round()}% target adherence).',
      );
    } else {
      growthAreas.add(
        'Protein target missed on ${(100 - proteinAdherence).round()}% of days.',
      );
      actionItems.add(
        'Incorporate a high-protein breakfast and post-workout shake.',
      );
    }

    if (avgSleep >= 7.0) {
      strengths.add(
        'Optimal sleep duration (${avgSleep.toStringAsFixed(1)}h average).',
      );
    } else {
      growthAreas.add(
        'Sleep duration averaged below 7 hours (${avgSleep.toStringAsFixed(1)}h).',
      );
      actionItems.add('Enforce a 30-minute wind-down routine before sleep.');
    }

    // Grade Calculation
    // Without a known protein rate the protein part is left out and the
    // rest is scaled to the full 100 points (unknown is not 0% adherence).
    final restScore =
        (consistencyPct * 0.4) +
        ((avgSleep / 8.0).clamp(0.0, 1.0) * 100 * 0.2) +
        (volumeChangePct >= 0 ? 10.0 : 0.0);
    final score = (proteinKnown || recentNutrition.isEmpty)
        ? restScore + (proteinAdherence * 0.3)
        : restScore * (100.0 / 70.0);

    String grade;
    if (score >= 90) {
      grade = 'A+';
    } else if (score >= 80) {
      grade = 'A';
    } else if (score >= 70) {
      grade = 'B+';
    } else if (score >= 60) {
      grade = 'B';
    } else if (score >= 50) {
      grade = 'C';
    } else {
      grade = 'D';
    }

    String nextWeekFocus;
    if (growthAreas.isNotEmpty) {
      nextWeekFocus = 'Priority: Address ${growthAreas.first.toLowerCase()}';
    } else {
      nextWeekFocus =
          'Priority: Continue progressive overload and maintain peak recovery';
    }

    final proteinText = (proteinKnown || recentNutrition.isEmpty)
        ? 'Protein adherence at ${proteinAdherence.round()}%.'
        : 'Protein adherence could not be checked (foods without protein values).';
    final summaryText =
        'Weekly Performance Grade: $grade. Completed $workoutsCompleted workouts (${currentVolume.toInt()} kg total volume). $proteinText Average sleep: ${avgSleep.toStringAsFixed(1)}h.';

    return WeeklyAthleteReport(
      weekStartDate: sevenDaysAgo,
      weekEndDate: now,
      grade: grade,
      workoutsCompleted: workoutsCompleted,
      workoutsTarget: workoutsTarget,
      volumeProgressionPercentage: double.parse(
        volumeChangePct.toStringAsFixed(1),
      ),
      totalVolumeKg: currentVolume,
      personalRecords: prs,
      consistencyPercentage: double.parse(consistencyPct.toStringAsFixed(1)),
      averageDailyCalories: avgCalories,
      proteinAdherencePercentage: double.parse(
        proteinAdherence.toStringAsFixed(1),
      ),
      averageSleepHours: double.parse(avgSleep.toStringAsFixed(1)),
      averageReadinessScore: avgReadiness,
      weightDeltaKg: double.parse(weightChange.toStringAsFixed(1)),
      strengths: strengths,
      growthAreas: growthAreas,
      nextWeekFocus: nextWeekFocus,
      actionItems: actionItems.isNotEmpty
          ? actionItems
          : ['Maintain consistent training schedule and nutrition targets.'],
      summaryText: summaryText,
    );
  }
}
