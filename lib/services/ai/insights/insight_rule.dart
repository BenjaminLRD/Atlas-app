import '../../../models/daily_nutrition.dart';
import '../../../models/health_metric.dart';
import '../../../models/user_profile.dart';
import '../../../models/weight_goal.dart';
import '../../../models/workout_history.dart';
import '../../analytics/workout_analytics_service.dart';
import 'insight_model.dart';

/// Aggregated data context supplied to rules for proactive evaluation.
class InsightContext {
  final HealthMetric todayHealth;
  final double recoveryScore;

  /// True only when sleep, HRV or heart rate backs [recoveryScore]. Rules do
  /// not fire on an unmeasured score.
  final bool recoveryMeasured;
  final bool isDeloadRecommended;
  final DailyNutrition dailyNutrition;
  final WeightGoal? weightGoal;
  final UserProfile? userProfile;
  final List<WorkoutHistory> workoutHistory;
  final VolumeAnalytics volumeAnalytics;
  final ConsistencyAnalytics consistencyAnalytics;
  final PersonalRecordSummary personalRecords;
  final DateTime now;

  const InsightContext({
    required this.todayHealth,
    required this.recoveryScore,
    this.recoveryMeasured = false,
    required this.isDeloadRecommended,
    required this.dailyNutrition,
    this.weightGoal,
    this.userProfile,
    required this.workoutHistory,
    required this.volumeAnalytics,
    required this.consistencyAnalytics,
    required this.personalRecords,
    required this.now,
  });
}

/// Abstract contract for individual domain insight evaluation rules.
abstract class InsightRule {
  String get ruleName;
  Future<List<CoachInsight>> evaluate(InsightContext context);
}

/// Rule 1: Evaluates recovery scores, deload status, and sleep metrics.
class RecoveryInsightRule implements InsightRule {
  const RecoveryInsightRule();

  @override
  String get ruleName => 'Recovery & Sleep Intelligence Rule';

  @override
  Future<List<CoachInsight>> evaluate(InsightContext context) async {
    final insights = <CoachInsight>[];

    // A. Critical Recovery / Deload Warning
    if (context.recoveryMeasured &&
        (context.recoveryScore < 50 || context.isDeloadRecommended)) {
      insights.add(
        CoachInsight(
          id: 'ins_rec_warn_${context.now.millisecondsSinceEpoch}',
          type: InsightType.recoveryWarning,
          priority: InsightPriority.critical,
          title: 'High Systemic Fatigue Detected',
          message:
              'Your recovery score is ${context.recoveryScore.round()}% (Low readiness). Reduce training volume today or take an active recovery rest day.',
          rationale:
              'Elevated muscle damage and high cumulative fatigue increase injury risk.',
          actionType: InsightActionType.reviewRecovery,
          actionLabel: 'Review Recovery',
          timestamp: context.now,
        ),
      );
    }

    // B. Sleep Duration Recommendation (< 6.5h)
    final sleepHours = context.todayHealth.sleepHours;
    if (sleepHours > 0 && sleepHours < 6.5) {
      insights.add(
        CoachInsight(
          id: 'ins_sleep_${context.now.millisecondsSinceEpoch}',
          type: InsightType.sleepRecommendation,
          priority: InsightPriority.high,
          title: 'Sleep Duration Below Target',
          message:
              'You recorded only ${context.todayHealth.formattedSleep.isNotEmpty ? context.todayHealth.formattedSleep : "${sleepHours.toStringAsFixed(1)}h"} of sleep last night. Prioritize 8+ hours tonight to optimize muscle repair.',
          rationale:
              'Growth hormone and protein synthesis peak during deep slow-wave sleep.',
          actionType: InsightActionType.reviewRecovery,
          actionLabel: 'Check Readiness',
          timestamp: context.now,
        ),
      );
    }

    return insights;
  }
}

/// Rule 2: Evaluates protein intake, meal timing, and weight plateau adjustments.
class NutritionInsightRule implements InsightRule {
  const NutritionInsightRule();

  @override
  String get ruleName => 'Nutrition & Target Tracking Rule';

  @override
  Future<List<CoachInsight>> evaluate(InsightContext context) async {
    final insights = <CoachInsight>[];
    final targetProtein = context.dailyNutrition.targets.proteinGrams > 0
        ? context.dailyNutrition.targets.proteinGrams
        : 150.0;
    // Null when some food has no protein value: the amount still missing is
    // then unknown, so no reminder claims a deficit.
    final remainingProtein = context.dailyNutrition.proteinRemaining(
      targetProtein,
    );

    // A. Protein Deficit Reminder
    if (remainingProtein != null && remainingProtein >= 35.0) {
      insights.add(
        CoachInsight(
          id: 'ins_protein_${context.now.millisecondsSinceEpoch}',
          type: InsightType.proteinReminder,
          priority: InsightPriority.medium,
          title: 'Protein Target Reminder',
          message:
              'You have ${remainingProtein.round()}g of protein remaining to reach your ${targetProtein.round()}g daily target.',
          rationale:
              'Consistent protein distribution across the day maximizes muscle protein synthesis (MPS).',
          actionType: InsightActionType.logProtein,
          actionLabel: 'Log High-Protein Food',
          timestamp: context.now,
        ),
      );
    }

    // B. Calorie Goal / Plateau Adjustment Suggestion
    if (context.weightGoal != null) {
      final goal = context.weightGoal!;
      final targetCals = goal.dailyCalorieTarget;
      final totals = context.dailyNutrition.totalsConsumed;
      final consumedCals = totals.calories;
      // With unknown calories the figure is a minimum: being above the target
      // is still certain, but by how much is only "at least".
      final atLeast = totals.caloriesComplete ? '' : 'at least ';

      // If cut/bulk calorie intake has heavily deviated or athlete needs a calorie shift
      if (goal.type == WeightGoalType.lose &&
          consumedCals > (targetCals + 400)) {
        insights.add(
          CoachInsight(
            id: 'ins_cals_${context.now.millisecondsSinceEpoch}',
            type: InsightType.calorieAdjustment,
            priority: InsightPriority.medium,
            title: 'Calorie Surplus Alert',
            message:
                'Today\'s intake is $atLeast${(consumedCals - targetCals).round()} kcal above your cutting target (${targetCals.round()} kcal). Aim to balance dinner.',
            rationale:
                'Maintaining target energy deficit ensures steady weekly fat loss rate.',
            actionType: InsightActionType.adjustCalories,
            actionLabel: 'Review Diet Plan',
            timestamp: context.now,
          ),
        );
      }
    }

    return insights;
  }
}

/// Rule 3: Evaluates workout consistency, missed session gaps, excessive volume, and PR potential.
class TrainingInsightRule implements InsightRule {
  const TrainingInsightRule();

  @override
  String get ruleName => 'Training & Progression Intelligence Rule';

  @override
  Future<List<CoachInsight>> evaluate(InsightContext context) async {
    final insights = <CoachInsight>[];

    // A. Missed Workout / Inactivity Gap (>= 3 days without workout)
    if (context.workoutHistory.isNotEmpty) {
      final lastWorkoutDate = context.workoutHistory.first.dateCompleted;
      final daysSinceLastWorkout = context.now
          .difference(lastWorkoutDate)
          .inDays;

      if (daysSinceLastWorkout >= 3) {
        insights.add(
          CoachInsight(
            id: 'ins_missed_${context.now.millisecondsSinceEpoch}',
            type: InsightType.missedWorkout,
            priority: InsightPriority.high,
            title: 'Time to Re-Engage',
            message:
                'It has been $daysSinceLastWorkout days since your last workout. Ready to hit a session today?',
            rationale:
                'Training frequency of 3-5 sessions weekly yields optimal hypertrophy.',
            actionType: InsightActionType.startWorkout,
            actionLabel: 'Start Today\'s Workout',
            timestamp: context.now,
          ),
        );
      }
    }

    // B. Personal Record (PR) Opportunity
    if (context.recoveryMeasured &&
        context.recoveryScore >= 82 &&
        context.consistencyAnalytics.currentStreak >= 1) {
      insights.add(
        CoachInsight(
          id: 'ins_pr_${context.now.millisecondsSinceEpoch}',
          type: InsightType.personalRecordOpportunity,
          priority: InsightPriority.low,
          title: 'PR Opportunity Window',
          message:
              'Optimal recovery (${context.recoveryScore.round()}%) and solid momentum! Great day to push for a top set or PR.',
          rationale:
              'High neuromuscular readiness allows maximum force production with lower fatigue accumulation.',
          actionType: InsightActionType.startWorkout,
          actionLabel: 'Launch Workout',
          timestamp: context.now,
        ),
      );
    }

    // C. Excessive Volume Alert (weekly volume > 160% of expected average)
    if (context.volumeAnalytics.weeklyVolume > 15000 &&
        context.volumeAnalytics.totalLifetimeVolume > 0 &&
        context.volumeAnalytics.weeklyVolume >
            (context.volumeAnalytics.totalLifetimeVolume / 3)) {
      insights.add(
        CoachInsight(
          id: 'ins_vol_${context.now.millisecondsSinceEpoch}',
          type: InsightType.excessiveVolume,
          priority: InsightPriority.high,
          title: 'Training Volume Surge',
          message:
              'Your weekly volume has surged to ${context.volumeAnalytics.weeklyVolume.round()} kg. Monitor joint recovery closely.',
          rationale:
              'Uncontrolled acute volume spikes can trigger tendonitis and central fatigue.',
          actionType: InsightActionType.reviewRecovery,
          actionLabel: 'Review Recovery',
          timestamp: context.now,
        ),
      );
    }

    return insights;
  }
}
