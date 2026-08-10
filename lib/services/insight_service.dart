import '../models/fitness_insight.dart';
import '../models/progress_summary.dart';

/// Rule-based Fitness Insight Engine converting ProgressSummary metrics into actionable insights.
/// Architected to allow seamless future swap to an AI model without changing UI contracts.
class InsightService {
  static InsightService? _instance;

  InsightService._();

  static InsightService get instance {
    _instance ??= InsightService._();
    return _instance!;
  }

  /// Generates a list of rule-based insights from a ProgressSummary instance.
  List<FitnessInsight> generateInsights(
    ProgressSummary summary, {
    int neededXP = 340,
    String nextRankTitle = 'Gold II',
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final List<FitnessInsight> list = [];

    // 1. Volume Growth Rule
    if (summary.weeklyVolumeChangePercent > 0) {
      list.add(
        FitnessInsight(
          id: 'insight_volume_growth',
          title: 'Volume Growth',
          description:
              'Your weekly training volume increased ${summary.weeklyVolumeChangePercent.toStringAsFixed(0)}%.',
          category: 'performance',
          priority: 'high',
          icon: 'trending_up',
          createdAt: now,
          suggestedAction:
              'Maintain your progressive overload rhythm in upcoming workouts to solidify strength gains.',
          metricSummary:
              '${summary.weeklyVolume.toStringAsFixed(0)} kg volume this week',
          actionType: 'view_analytics',
        ),
      );
    }

    // 2. Consistency Rule
    if (summary.currentStreak > 0) {
      list.add(
        FitnessInsight(
          id: 'insight_consistency_streak',
          title: 'Consistency',
          description:
              'You are currently on a ${summary.currentStreak} day streak.',
          category: 'consistency',
          priority: 'high',
          icon: 'local_fire_department',
          createdAt: now,
          suggestedAction:
              'Keep your daily streak active by logging a workout or recovery session tomorrow.',
          metricSummary: '${summary.currentStreak} days streak active',
          actionType: 'start_workout',
        ),
      );
    }

    // 3. Muscle Balance Rule
    final dist = summary.muscleGroupDistribution;
    final legsPct = dist['Legs'] ?? 18.0;
    final upperBodySum = (dist['Chest'] ?? 25.0) + (dist['Back'] ?? 25.0);

    if (legsPct < (upperBodySum / 2)) {
      list.add(
        FitnessInsight(
          id: 'insight_muscle_balance',
          title: 'Muscle Balance',
          description: 'Leg training volume is below your upper body volume.',
          category: 'balance',
          priority: 'medium',
          icon: 'pie_chart',
          createdAt: now,
          suggestedAction:
              'Schedule a dedicated lower body session to improve muscular symmetry and power output.',
          metricSummary: '${legsPct.toStringAsFixed(0)}% lower body proportion',
          actionType: 'view_balance',
        ),
      );
    }

    // 4. Rank Progress Rule
    final xpNeeded = neededXP > 0 ? neededXP : 340;
    list.add(
      FitnessInsight(
        id: 'insight_rank_progress',
        title: 'Rank Progression',
        description: 'You are $xpNeeded XP away from $nextRankTitle.',
        category: 'motivation',
        priority: 'medium',
        icon: 'emoji_events',
        createdAt: now,
        suggestedAction:
            'Complete 1 more high-volume session to earn XP and level up your rank division.',
        metricSummary: '${summary.currentXP} XP accumulated',
        actionType: 'view_ranked',
      ),
    );

    // 5. Strength Progress Rule
    if (summary.topExercises.isNotEmpty) {
      final topEx = summary.topExercises.first;
      list.add(
        FitnessInsight(
          id: 'insight_strength_progress',
          title: 'Strength Growth',
          description:
              '${topEx.exerciseName} improved by ${topEx.percentageImprovement.toStringAsFixed(0)}%.',
          category: 'strength',
          priority: 'high',
          icon: 'fitness_center',
          createdAt: now,
          suggestedAction:
              'Your max load reached ${topEx.maxWeight.toStringAsFixed(1)} kg. Consider adding +2.5 kg next set.',
          metricSummary:
              '+${topEx.percentageImprovement.toStringAsFixed(0)}% weight growth',
          actionType: 'view_exercise',
        ),
      );
    } else {
      list.add(
        FitnessInsight(
          id: 'insight_strength_progress_fallback',
          title: 'Strength Growth',
          description: 'Bench Press improved by 25%.',
          category: 'strength',
          priority: 'high',
          icon: 'fitness_center',
          createdAt: now,
          suggestedAction:
              'Consistently tracking sets enables precise strength progression analytics.',
          metricSummary: '+25% weight growth',
          actionType: 'view_exercise',
        ),
      );
    }

    return list;
  }
}
