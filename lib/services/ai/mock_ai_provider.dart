import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import 'ai_provider.dart';

/// Development testing implementation of [AIProvider].
/// Generates realistic, context-aware responses grounded in the user's [FitnessContext].
class MockAIProvider implements AIProvider {
  const MockAIProvider();

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
  }) async {
    // Simulate natural response latency
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = message.toLowerCase().trim();

    // 1. Nutrition Intent
    if (normalized.contains('protein') ||
        normalized.contains('calorie') ||
        normalized.contains('diet') ||
        normalized.contains('macro') ||
        normalized.contains('food') ||
        normalized.contains('meal') ||
        normalized.contains('eat')) {
      final goal = context.userGoal;
      final targetProtein = (goal?.targetProtein ?? 140).round();
      final targetCalories = (goal?.targetCalories ?? 2200).round();
      final hitRate = context.nutritionSummary.proteinGoalHitPercentage.toStringAsFixed(0);
      final streak = context.nutritionProgress.currentNutritionStreak;

      return 'Based on your protocol, your daily protein target is ${targetProtein}g and calorie target is $targetCalories kcal. '
          'Over your recent history, your protein goal hit rate is $hitRate% with a $streak-day nutrition streak. '
          'To hit your daily target easily, space out 30-40g of protein across 4 meals (e.g. eggs for breakfast, chicken or lentils for lunch, whey post-workout, and paneer/fish for dinner).';
    }

    // 2. Training & Workout Intent
    if (normalized.contains('workout') ||
        normalized.contains('training') ||
        normalized.contains('exercise') ||
        normalized.contains('rest') ||
        normalized.contains('volume') ||
        normalized.contains('lift') ||
        normalized.contains('streak')) {
      final summary = context.progressSummary;
      final streak = summary.currentStreak;
      final volume = summary.totalVolume.toStringAsFixed(0);
      final total = summary.totalWorkouts;

      if (normalized.contains('rest') && streak >= 3) {
        return 'You are currently on a $streak-day workout streak with $volume kg total volume logged across $total sessions. '
            'Since you have trained for $streak consecutive days, taking an active recovery day (light walking or foam rolling) will boost your muscle repair and prevent central nervous system fatigue.';
      }

      return 'You have completed $total total workouts with a cumulative volume of $volume kg. '
          'Your active training streak is $streak days. To maximize hypertrophy and strength, focus on progressive overload—gradually increasing weight or reps while keeping 1-2 reps in reserve.';
    }

    // 3. Rank, XP, & Gamification Intent
    if (normalized.contains('rank') ||
        normalized.contains('xp') ||
        normalized.contains('division') ||
        normalized.contains('tier') ||
        normalized.contains('badge') ||
        normalized.contains('level')) {
      final progress = context.userProgress;
      final fullRank = progress.fullRank;
      final totalXP = progress.totalXP;
      final badges = progress.achievements.length;

      return 'You are currently ranked **$fullRank** with **$totalXP total XP**! '
          'You have completed ${progress.completedWorkouts} workouts and unlocked $badges achievement badges. '
          'Earn XP faster by finishing planned workouts (+50 XP), hitting daily protein goals (+50 XP), and logging consecutive days!';
    }

    // 4. General / Fallback Intent
    final userName = context.userProfile?.name ?? 'Athlete';
    final goalType = context.userGoal?.goalType.name ?? 'Muscle Gain';

    return 'Hello $userName! Your current fitness objective is set to **$goalType**. '
        'I am monitoring your daily nutrition targets, training volume, and rank progress in real time. '
        'Ask me specific questions about your protein targets, workout recovery, or XP rank progress anytime!';
  }
}
