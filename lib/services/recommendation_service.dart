import '../data/gamification_service.dart';
import '../models/fitness_context.dart';
import '../models/recommendation.dart';
import '../models/user_goal.dart';

/// Pluggable interface for AI recommendation generation engines.
/// Can be backed by rule-based evaluation engines or future LLM/GenAI models.
abstract class RecommendationEngine {
  List<Recommendation> generateRecommendations(FitnessContext context);
}

/// Rule-based recommendation engine evaluating user goals, training volume,
/// nutrition adherence, and gamification rank progression.
class RuleBasedRecommendationEngine implements RecommendationEngine {
  const RuleBasedRecommendationEngine();

  @override
  List<Recommendation> generateRecommendations(FitnessContext context) {
    final List<Recommendation> recommendations = [];
    final now = DateTime.now();
    final expiration = now.add(const Duration(days: 7));

    // 1. GOAL ALIGNMENT RULES
    if (context.userGoal != null) {
      final goal = context.userGoal!;
      final weightDiff = (goal.targetWeight - goal.currentWeight).abs();

      if (goal.goalType == FitnessGoalType.muscleGain) {
        recommendations.add(
          Recommendation(
            id: 'rec_goal_muscle_gain',
            title: 'Optimize Hypertrophy Surplus',
            description:
                'Target ${goal.targetCalories.round()} kcal daily with ${goal.targetProtein.round()}g protein to support lean muscle synthesis.',
            category: RecommendationCategory.nutrition,
            priority: RecommendationPriority.high,
            actionTitle: 'View Macro Plan',
            actionRoute: '/diet-plan',
            reasoning:
                'Your current goal is Muscle Gain with a target weight of ${goal.targetWeight}kg (${weightDiff.toStringAsFixed(1)}kg remaining).',
            metricTrigger: 'Target Surplus: ${goal.targetCalories.round()} kcal/day',
            createdAt: now,
            expiresAt: expiration,
          ),
        );
      } else if (goal.goalType == FitnessGoalType.fatLoss) {
        recommendations.add(
          Recommendation(
            id: 'rec_goal_fat_loss',
            title: 'Maintain Caloric Deficit',
            description:
                'Keep daily intake around ${goal.targetCalories.round()} kcal while prioritizing ${goal.targetProtein.round()}g protein to preserve muscle.',
            category: RecommendationCategory.nutrition,
            priority: RecommendationPriority.high,
            actionTitle: 'Track Today\'s Meals',
            actionRoute: '/diet-plan',
            reasoning:
                'Your primary objective is Fat Loss targeting ${goal.targetWeight}kg.',
            metricTrigger: 'Target Deficit: ${goal.targetCalories.round()} kcal/day',
            createdAt: now,
            expiresAt: expiration,
          ),
        );
      } else if (goal.goalType == FitnessGoalType.strength) {
        recommendations.add(
          Recommendation(
            id: 'rec_goal_strength',
            title: 'Focus on Heavy Progressive Overload',
            description:
                'Aim for low rep ranges (3–6 reps) on main compound lifts with 2–3 min rest intervals.',
            category: RecommendationCategory.training,
            priority: RecommendationPriority.high,
            actionTitle: 'Log Workout',
            actionRoute: '/workout',
            reasoning:
                'Your goal is Strength. Heavy compound lifts drive neuromuscular adaptation.',
            metricTrigger: 'Goal Type: Strength',
            createdAt: now,
            expiresAt: expiration,
          ),
        );
      }
    }

    // 2. NUTRITION CONSISTENCY RULES
    final summary = context.nutritionSummary;
    if (summary.proteinGoalHitPercentage < 70.0) {
      recommendations.add(
        Recommendation(
          id: 'rec_nutrition_protein_boost',
          title: 'Boost Daily Protein Intake',
          description:
              'You hit your protein target in ${summary.proteinGoalHitPercentage.round()}% of logged days. Adding a high-protein snack can accelerate recovery.',
          category: RecommendationCategory.nutrition,
          priority: RecommendationPriority.high,
          actionTitle: 'Log Food',
          actionRoute: '/diet-plan',
          reasoning:
              'Protein hit rate is currently ${summary.proteinGoalHitPercentage.round()}% (below optimal 70%+ threshold).',
          metricTrigger: 'Protein Hit Rate: ${summary.proteinGoalHitPercentage.round()}%',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    }

    if (context.nutritionProgress.currentNutritionStreak >= 3) {
      recommendations.add(
        Recommendation(
          id: 'rec_nutrition_streak_keep_going',
          title: '${context.nutritionProgress.currentNutritionStreak}-Day Nutrition Streak! 🔥',
          description:
              'Great consistency! Keep logging your planned meals to extend your nutrition streak and earn bonus XP.',
          category: RecommendationCategory.gamification,
          priority: RecommendationPriority.medium,
          actionTitle: 'View Nutrition',
          actionRoute: '/diet-plan',
          reasoning:
              'You have an active nutrition streak of ${context.nutritionProgress.currentNutritionStreak} days.',
          metricTrigger: 'Nutrition Streak: ${context.nutritionProgress.currentNutritionStreak} days',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    }

    // 3. TRAINING & VOLUME RULES
    final progress = context.progressSummary;
    if (progress.currentStreak >= 3) {
      recommendations.add(
        Recommendation(
          id: 'rec_training_recovery_check',
          title: 'Prioritize Active Recovery',
          description:
              'You have trained ${progress.currentStreak} days in a row! Ensure adequate sleep, hydration, and mobility work today.',
          category: RecommendationCategory.recovery,
          priority: RecommendationPriority.medium,
          actionTitle: 'Log Active Recovery',
          actionRoute: '/workout',
          reasoning:
              'Consecutive training streak reached ${progress.currentStreak} days.',
          metricTrigger: 'Active Workout Streak: ${progress.currentStreak} days',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    } else if (context.workoutHistory.isEmpty) {
      recommendations.add(
        Recommendation(
          id: 'rec_training_first_workout',
          title: 'Start Your First Workout',
          description:
              'Kickstart your fitness journey! Log your first workout session to begin tracking progressive overload and volume.',
          category: RecommendationCategory.training,
          priority: RecommendationPriority.high,
          actionTitle: 'Start Workout',
          actionRoute: '/workout',
          reasoning: 'No completed workout sessions recorded yet.',
          metricTrigger: 'Completed Workouts: 0',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    }

    // 4. GAMIFICATION & RANK PROGRESSION RULES
    final userProgress = context.userProgress;
    final nextRankDetails = GamificationService().getNextRankRequirement(
      userProgress.totalXP,
      userProgress.rankedUnlocked,
    );
    final int xpNeeded = (nextRankDetails['neededXP'] as num?)?.toInt() ?? 0;
    final String nextRankName =
        nextRankDetails['nextRank'] as String? ?? 'Next Rank';

    if (xpNeeded > 0 && xpNeeded <= 150) {
      recommendations.add(
        Recommendation(
          id: 'rec_gamification_rank_up_close',
          title: 'Rank Up Impending! ($xpNeeded XP Needed)',
          description:
              'You are only $xpNeeded XP away from promoting to $nextRankName! Complete today\'s workout or log meals to rank up.',
          category: RecommendationCategory.gamification,
          priority: RecommendationPriority.high,
          actionTitle: 'Earn XP Now',
          actionRoute: '/workout',
          reasoning:
              'Current rank: ${userProgress.fullRank}. Only $xpNeeded XP remaining until $nextRankName.',
          metricTrigger: 'XP Remaining: $xpNeeded',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    }

    // 5. MINDSET & CONSISTENCY FALLBACK
    if (recommendations.isEmpty) {
      recommendations.add(
        Recommendation(
          id: 'rec_mindset_general',
          title: 'Consistency Drives Results',
          description:
              'Stay disciplined with your daily routines. Log your meals and workouts consistently for steady progress.',
          category: RecommendationCategory.mindset,
          priority: RecommendationPriority.low,
          actionTitle: 'Explore Dashboard',
          actionRoute: '/dashboard',
          reasoning: 'General consistency recommendation.',
          metricTrigger: 'Default Guidance',
          createdAt: now,
          expiresAt: expiration,
        ),
      );
    }

    return recommendations;
  }
}

/// Service responsible for managing recommendation evaluation, deduplication,
/// anti-spam filtering, and dismissal tracking.
class RecommendationService {
  final RecommendationEngine _engine;

  const RecommendationService([
    this._engine = const RuleBasedRecommendationEngine(),
  ]);

  /// Evaluates context and returns active recommendations, filtering out
  /// dismissed or expired recommendations and preventing duplicate titles.
  List<Recommendation> evaluateContext(
    FitnessContext context, {
    List<Recommendation> existingRecommendations = const [],
  }) {
    final generated = _engine.generateRecommendations(context);
    final dismissedIds = existingRecommendations
        .where((r) => r.isDismissed)
        .map((r) => r.id)
        .toSet();

    final List<Recommendation> active = [];
    final Set<String> seenTitles = {};

    for (final rec in generated) {
      if (dismissedIds.contains(rec.id)) continue;
      if (rec.isExpired) continue;
      if (seenTitles.contains(rec.title)) continue;

      seenTitles.add(rec.title);
      active.add(rec);
    }

    // Sort by priority (high > medium > low)
    active.sort((a, b) {
      const priorityOrder = {
        RecommendationPriority.high: 0,
        RecommendationPriority.medium: 1,
        RecommendationPriority.low: 2,
      };
      return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
    });

    return active;
  }
}
