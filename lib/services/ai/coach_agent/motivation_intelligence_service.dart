import '../memory/fitness_memory.dart';
import '../memory/preference_profile.dart';

/// Service analyzing user consistency, streaks, and fitness milestones to generate personalized motivation.
class MotivationIntelligenceService {
  static MotivationIntelligenceService? _instance;
  static MotivationIntelligenceService get instance =>
      _instance ??= MotivationIntelligenceService();

  /// Generates a tailored motivational message based on recent workouts, streak, and weekly target.
  String generateEncouragement({
    required int completedWorkoutsThisWeek,
    required int weeklyGoal,
    int currentStreakDays = 0,
    bool isDeloadDay = false,
    String? recentPrExercise,
    PreferenceProfile? preferenceProfile,
  }) {
    final profile =
        preferenceProfile ?? FitnessMemory.instance.getPreferenceProfile();
    final tone = profile.coachPersonalityPreference.isNotEmpty
        ? profile.coachPersonalityPreference.toLowerCase()
        : 'encouraging';

    if (isDeloadDay) {
      return 'Active recovery is where muscle growth and neural restoration happen. Prioritize sleep and hydration today to prepare for next week\'s heavy cycles.';
    }

    if (recentPrExercise != null && recentPrExercise.isNotEmpty) {
      return 'Incredible effort setting a new personal record on $recentPrExercise! Your progressive overload discipline is paying off.';
    }

    if (completedWorkoutsThisWeek >= weeklyGoal) {
      return 'You\'ve crushed all $weeklyGoal scheduled workouts for the week! Exceptional dedication to your training protocol.';
    }

    final remaining = weeklyGoal - completedWorkoutsThisWeek;
    if (remaining == 1) {
      return 'You have completed $completedWorkoutsThisWeek workouts this week. One more session reaches your weekly goal of $weeklyGoal!';
    }

    if (currentStreakDays >= 5) {
      return 'You are on a $currentStreakDays-day consistency streak! Maintain this athletic momentum one session at a time.';
    }

    if (tone.contains('intense') || tone.contains('drill')) {
      return 'No excuses today. Step into the gym, lock in your focus, and execute every single set with purpose.';
    }

    return 'Every workout you complete brings you closer to your fitness goals. Focus on great technique and steady progress today!';
  }
}
