import '../../data/gamification_service.dart';
import '../../models/brief_item.dart';
import '../../models/daily_brief.dart';
import '../../models/fitness_context.dart';
import '../../models/user_goal.dart';

/// Service responsible for analyzing user [FitnessContext] and generating
/// a proactive, actionable [DailyBrief] with prioritized insights.
class DailyBriefService {
  const DailyBriefService();

  /// Generates a comprehensive [DailyBrief] from current user context.
  DailyBrief generateBrief(FitnessContext context) {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final briefId = 'brief_$dateKey';

    final items = <BriefItem>[];

    // 1. TRAINING INSIGHTS
    final streak = context.progressSummary.currentStreak > 0
        ? context.progressSummary.currentStreak
        : context.userProgress.workoutStreak;
    final totalWorkouts = context.progressSummary.totalWorkouts;
    final totalVolume = context.progressSummary.totalVolume.round();

    if (streak >= 3) {
      items.add(BriefItem(
        title: 'High Workout Streak',
        description: 'You\'re on a fire $streak-day workout streak! Maintain your momentum today.',
        category: 'TRAINING',
        icon: 'local_fire_department',
        actionTitle: 'View Workouts',
        actionRoute: 'open_workout',
      ));
    } else if (totalWorkouts > 0) {
      items.add(BriefItem(
        title: 'Active Training Target',
        description: 'You have logged $totalWorkouts sessions with $totalVolume kg total volume lift. Keep pushing!',
        category: 'TRAINING',
        icon: 'fitness_center',
        actionTitle: 'View Routine',
        actionRoute: 'open_workout',
      ));
    } else {
      items.add(BriefItem(
        title: 'Kickstart Your Training',
        description: 'No workouts logged yet this cycle. Select a plan to begin building your streak!',
        category: 'TRAINING',
        icon: 'play_circle_outline',
        actionTitle: 'Start Workout',
        actionRoute: 'open_workout',
      ));
    }

    // 2. NUTRITION INSIGHTS
    final proteinHitRate = context.nutritionSummary.proteinGoalHitPercentage.round();
    final targetProtein = (context.userGoal?.targetProtein ?? 140).round();
    final targetCalories = (context.userGoal?.targetCalories ?? 2200).round();
    final nutritionStreak = context.nutritionProgress.currentNutritionStreak;

    if (proteinHitRate >= 80) {
      items.add(BriefItem(
        title: 'Optimal Protein Adherence',
        description: 'Protein hit rate is at $proteinHitRate%! Target is ${targetProtein}g daily.',
        category: 'NUTRITION',
        icon: 'restaurant',
        actionTitle: 'Log Nutrition',
        actionRoute: 'open_nutrition',
      ));
    } else if (nutritionStreak > 0) {
      items.add(BriefItem(
        title: 'Nutrition Consistency',
        description: 'You have a $nutritionStreak-day nutrition log streak. Aim for $targetCalories kcal today.',
        category: 'NUTRITION',
        icon: 'bolt',
        actionTitle: 'Log Meals',
        actionRoute: 'open_nutrition',
      ));
    } else {
      items.add(BriefItem(
        title: 'Fuel Target Alert',
        description: 'Target: ${targetProtein}g protein & $targetCalories kcal daily for optimal recovery.',
        category: 'NUTRITION',
        icon: 'restaurant_menu',
        actionTitle: 'Track Meals',
        actionRoute: 'open_nutrition',
      ));
    }

    // 3. GOALS INSIGHTS
    final goal = context.userGoal;
    if (goal != null) {
      final currentW = goal.currentWeight.toStringAsFixed(1);
      final targetW = goal.targetWeight.toStringAsFixed(1);
      final goalLabel = _getGoalLabel(goal.goalType);

      items.add(BriefItem(
        title: 'Goal Protocol: $goalLabel',
        description: 'Current: $currentW kg -> Target: $targetW kg. Protocol tuned for ${goal.fitnessLevel.name}.',
        category: 'GOALS',
        icon: 'flag',
        actionTitle: 'Adjust Goals',
        actionRoute: 'open_goals',
      ));
    } else {
      items.add(BriefItem(
        title: 'Set Your Fitness Goal',
        description: 'Define your target weight and activity level to unlock tailored calorie & macro targets.',
        category: 'GOALS',
        icon: 'edit_note',
        actionTitle: 'Setup Goal',
        actionRoute: 'open_goals',
      ));
    }

    // 4. GAMIFICATION INSIGHTS
    final rank = context.userProgress.currentRank;
    final division = context.userProgress.currentDivision;
    final totalXP = context.userProgress.totalXP;
    final gamificationService = GamificationService();
    final rankReq = gamificationService.getNextRankRequirement(
      totalXP,
      context.userProgress.rankedUnlocked,
    );
    final xpNeeded = rankReq['nextRankXP'] as int? ?? 1000;
    final xpDelta = xpNeeded > totalXP ? xpNeeded - totalXP : 0;

    if (xpDelta > 0) {
      items.add(BriefItem(
        title: 'Rank Progression: $rank $division',
        description: 'Earn $xpDelta more XP to reach the next tier! Current total: $totalXP XP.',
        category: 'GAMIFICATION',
        icon: 'emoji_events',
        actionTitle: 'View Rank',
        actionRoute: 'open_progress',
      ));
    } else {
      items.add(BriefItem(
        title: 'Rank Level: $rank $division',
        description: 'You\'ve accumulated $totalXP XP! Complete challenges to climb higher.',
        category: 'GAMIFICATION',
        icon: 'military_tech',
        actionTitle: 'Leaderboard',
        actionRoute: 'open_progress',
      ));
    }

    // Sort items by priority / category relevance
    items.sort((a, b) => _categoryPriority(a.category).compareTo(_categoryPriority(b.category)));

    // Derive primary focus area and headline
    final focusArea = items.isNotEmpty ? _getFocusAreaName(items.first.category) : 'General Fitness';
    final headline = _generateHeadline(streak, proteinHitRate, goal);
    final summary = _generateSummary(streak, proteinHitRate, focusArea);
    final contextSummary = 'streak:$streak|protein:$proteinHitRate|xp:$totalXP|workouts:$totalWorkouts';

    return DailyBrief(
      id: briefId,
      date: now,
      headline: headline,
      summary: summary,
      focusArea: focusArea,
      items: List.unmodifiable(items),
      priority: items.any((i) => i.category == 'TRAINING' || i.category == 'NUTRITION') ? 1 : 2,
      createdAt: now,
      isRead: false,
      contextSummary: contextSummary,
    );
  }

  int _categoryPriority(String category) {
    switch (category.toUpperCase()) {
      case 'TRAINING':
        return 1;
      case 'NUTRITION':
        return 2;
      case 'GOALS':
        return 3;
      case 'GAMIFICATION':
        return 4;
      default:
        return 5;
    }
  }

  String _getFocusAreaName(String category) {
    switch (category.toUpperCase()) {
      case 'TRAINING':
        return 'Strength & Training';
      case 'NUTRITION':
        return 'Nutritional Balance';
      case 'GOALS':
        return 'Goal Realization';
      case 'GAMIFICATION':
        return 'Rank & Progress';
      default:
        return 'Daily Fitness Protocol';
    }
  }

  String _getGoalLabel(FitnessGoalType type) {
    switch (type) {
      case FitnessGoalType.muscleGain:
        return 'Muscle Gain';
      case FitnessGoalType.fatLoss:
        return 'Fat Loss';
      case FitnessGoalType.maintenance:
        return 'Maintenance';
      case FitnessGoalType.strength:
        return 'Pure Strength';
      case FitnessGoalType.endurance:
        return 'Endurance Build';
    }
  }

  String _generateHeadline(int streak, int proteinHitRate, UserGoal? goal) {
    if (streak >= 3) {
      return 'Peak Training Momentum!';
    } else if (proteinHitRate >= 80) {
      return 'Nutritional Targets On Track!';
    } else if (goal != null && goal.goalType == FitnessGoalType.fatLoss) {
      return 'Fat Loss & Recovery Focus';
    } else if (goal != null && goal.goalType == FitnessGoalType.muscleGain) {
      return 'Hypertrophy & Fuel Protocol';
    } else {
      return 'Your Daily Performance Brief';
    }
  }

  String _generateSummary(int streak, int proteinHitRate, String focusArea) {
    return 'Today\'s key focus is $focusArea. Stay disciplined on nutrition and complete your scheduled training to keep advancing.';
  }
}
