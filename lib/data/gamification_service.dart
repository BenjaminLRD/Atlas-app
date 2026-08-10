import '../models/daily_nutrition.dart';
import '../models/user_progress.dart';
import '../models/workout_history.dart';
import 'local_storage.dart';

/// Rank Tier Definition containing tier name, division, minimum XP, and full title
class RankInfo {
  final String tier;
  final String division;
  final int minXP;

  const RankInfo({
    required this.tier,
    required this.division,
    required this.minXP,
  });

  String get fullTitle =>
      division.isEmpty || division == 'Unranked' ? tier : '$tier $division';
}

/// Gamification and Ranked Progression Service for managing XP, unlocking ranks,
/// calculating tier/division progression, and awarding milestone bonuses.
class GamificationService {

  /// Complete competitive rank structure ordered by minimum XP requirement
  static const List<RankInfo> rankStructure = [
    RankInfo(tier: 'Bronze', division: 'IV', minXP: 500),
    RankInfo(tier: 'Bronze', division: 'III', minXP: 750),
    RankInfo(tier: 'Bronze', division: 'II', minXP: 1000),
    RankInfo(tier: 'Bronze', division: 'I', minXP: 1250),
    RankInfo(tier: 'Silver', division: 'IV', minXP: 1500),
    RankInfo(tier: 'Silver', division: 'III', minXP: 2000),
    RankInfo(tier: 'Silver', division: 'II', minXP: 2500),
    RankInfo(tier: 'Silver', division: 'I', minXP: 3000),
    RankInfo(tier: 'Gold', division: 'IV', minXP: 3500),
    RankInfo(tier: 'Gold', division: 'III', minXP: 4250),
    RankInfo(tier: 'Gold', division: 'II', minXP: 5000),
    RankInfo(tier: 'Gold', division: 'I', minXP: 5750),
    RankInfo(tier: 'Platinum', division: 'IV', minXP: 6500),
    RankInfo(tier: 'Platinum', division: 'III', minXP: 7500),
    RankInfo(tier: 'Platinum', division: 'II', minXP: 8500),
    RankInfo(tier: 'Platinum', division: 'I', minXP: 9500),
    RankInfo(tier: 'Diamond', division: 'IV', minXP: 11000),
    RankInfo(tier: 'Diamond', division: 'III', minXP: 12500),
    RankInfo(tier: 'Diamond', division: 'II', minXP: 14000),
    RankInfo(tier: 'Diamond', division: 'I', minXP: 15500),
    RankInfo(tier: 'Elite', division: 'IV', minXP: 17500),
    RankInfo(tier: 'Elite', division: 'III', minXP: 20000),
    RankInfo(tier: 'Elite', division: 'II', minXP: 23000),
    RankInfo(tier: 'Elite', division: 'I', minXP: 26000),
  ];

  /// Retrieve active user progress state from LocalStorage
  UserProgress getProgress() {
    return LocalStorage.getUserProgress();
  }

  /// Persist user progress state to LocalStorage
  Future<void> saveProgress(UserProgress progress) async {
    await LocalStorage.saveUserProgress(progress);
  }

  /// Award specified XP amount to user progress and recalculate rank tier.
  UserProgress addXP(int xpAmount, [UserProgress? currentProgress]) {
    final progress = currentProgress ?? getProgress();
    final newTotalXP = (progress.totalXP + xpAmount).clamp(0, 999999);
    final rankData = calculateRankFromXP(newTotalXP, progress.rankedUnlocked);

    return progress.copyWith(
      totalXP: newTotalXP,
      currentRank: rankData['tier'],
      currentDivision: rankData['division'],
    );
  }

  /// 1. Ranked Unlock System Check
  /// Users unlock Ranked mode after completing 5 or more workouts
  bool checkRankUnlock(int completedWorkouts) {
    return completedWorkouts >= 5;
  }

  /// 2. Rank Calculation Engine
  /// Returns tier and division mapping based on total XP and unlock status
  Map<String, String> calculateRankFromXP(int totalXP, bool isUnlocked) {
    if (!isUnlocked) {
      return {
        'tier': 'Unranked',
        'division': 'Unranked',
        'fullRank': 'Unranked',
      };
    }

    // Default initial unlocked rank is Bronze IV
    RankInfo activeRank = rankStructure.first;

    for (final rank in rankStructure) {
      if (totalXP >= rank.minXP) {
        activeRank = rank;
      } else {
        break;
      }
    }

    return {
      'tier': activeRank.tier,
      'division': activeRank.division,
      'fullRank': activeRank.fullTitle,
    };
  }

  /// 3. Get Next Rank Requirements
  /// Calculates next rank title, min XP required, and percentage completion
  Map<String, dynamic> getNextRankRequirement(int currentXP, bool isUnlocked) {
    if (!isUnlocked) {
      return {
        'nextRank': 'Bronze IV (Ranked Unlock)',
        'requiredXP': 500,
        'neededXP': (500 - currentXP).clamp(0, 500),
        'progressPercentage': (currentXP / 500.0).clamp(0.0, 1.0),
      };
    }

    RankInfo? nextRank;
    RankInfo currentRank = rankStructure.first;

    for (int i = 0; i < rankStructure.length; i++) {
      if (currentXP >= rankStructure[i].minXP) {
        currentRank = rankStructure[i];
        if (i + 1 < rankStructure.length) {
          nextRank = rankStructure[i + 1];
        } else {
          nextRank = null; // Maximum Rank Reached
        }
      }
    }

    if (nextRank == null) {
      return {
        'nextRank': 'Max Rank Reached',
        'requiredXP': currentRank.minXP,
        'neededXP': 0,
        'progressPercentage': 1.0,
      };
    }

    final int startXP = currentRank.minXP;
    final int targetXP = nextRank.minXP;
    final int span = targetXP - startXP;
    final int earnedInTier = currentXP - startXP;
    final double percentage = span > 0 ? (earnedInTier / span).clamp(0.0, 1.0) : 1.0;

    return {
      'nextRank': nextRank.fullTitle,
      'requiredXP': targetXP,
      'neededXP': targetXP - currentXP,
      'progressPercentage': percentage,
    };
  }

  /// 4. Workout XP Award Engine
  /// Awards XP based on rules:
  /// - Workout completed: +100 XP
  /// - Workout > 90% completion: +25 XP
  /// - 7-day streak milestone: +250 XP
  Future<UserProgress> awardWorkoutXP(WorkoutHistory workout, [UserProgress? currentProgress]) async {
    final current = currentProgress ?? getProgress();

    // Calculate XP Rewards
    int xpReward = 100; // Base workout completion reward

    if (workout.completionPercentage >= 90.0) {
      xpReward += 25; // Bonus for >90% completion
    }

    final int newCompletedWorkouts = current.completedWorkouts + 1;
    final bool isUnlocked = checkRankUnlock(newCompletedWorkouts);
    final int durationMins = (workout.durationSeconds / 60).ceil();

    final int newStreak = current.workoutStreak + 1;
    final int newLongestStreak = newStreak > current.longestStreak ? newStreak : current.longestStreak;

    // 7-day streak milestone bonus (+250 XP)
    if (newStreak > 0 && newStreak % 7 == 0) {
      xpReward += 250;
    }

    final int newTotalXP = current.totalXP + xpReward;
    final Map<String, String> rankMap = calculateRankFromXP(newTotalXP, isUnlocked);

    // Update achievements
    final List<String> updatedAchievements = List<String>.from(current.achievements);
    _checkAchievement(updatedAchievements, 'first_workout', newCompletedWorkouts >= 1);
    _checkAchievement(updatedAchievements, 'ranked_unlocked', isUnlocked);
    _checkAchievement(updatedAchievements, 'workout_5', newCompletedWorkouts >= 5);
    _checkAchievement(updatedAchievements, 'workout_25', newCompletedWorkouts >= 25);
    _checkAchievement(updatedAchievements, 'streak_7', newStreak >= 7);
    _checkAchievement(updatedAchievements, 'streak_30', newStreak >= 30);

    final UserProgress updatedProgress = current.copyWith(
      totalXP: newTotalXP,
      completedWorkouts: newCompletedWorkouts,
      rankedUnlocked: isUnlocked,
      currentRank: rankMap['tier']!,
      currentDivision: rankMap['division']!,
      workoutStreak: newStreak,
      longestStreak: newLongestStreak,
      totalWorkoutMinutes: current.totalWorkoutMinutes + durationMins,
      totalVolumeLifted: current.totalVolumeLifted + (workout.exercisesCompleted * 500.0),
      achievements: updatedAchievements,
    );

    await saveProgress(updatedProgress);
    return updatedProgress;
  }

  /// Alias method for backward compatibility
  Future<UserProgress> processWorkoutCompleted(WorkoutHistory workout) async {
    return awardWorkoutXP(workout);
  }

  /// Process XP reward for nutrition goals achieved
  Future<UserProgress> processNutritionGoalAchieved(DailyNutrition nutrition) async {
    final current = getProgress();

    final caloriesMet = nutrition.totalCaloriesConsumed >= (nutrition.targets.calories * 0.9);
    final proteinMet = nutrition.totalProteinConsumed >= (nutrition.targets.proteinGrams * 0.9);

    if (!caloriesMet || !proteinMet) {
      return current;
    }

    const rewardXP = 50;
    final newXP = current.totalXP + rewardXP;
    final isUnlocked = checkRankUnlock(current.completedWorkouts);
    final rankMap = calculateRankFromXP(newXP, isUnlocked);

    final updatedAchievements = List<String>.from(current.achievements);
    _checkAchievement(updatedAchievements, 'nutrition_goal', true);

    final updatedProgress = current.copyWith(
      totalXP: newXP,
      rankedUnlocked: isUnlocked,
      currentRank: rankMap['tier']!,
      currentDivision: rankMap['division']!,
      achievements: updatedAchievements,
    );

    await saveProgress(updatedProgress);
    return updatedProgress;
  }

  void _checkAchievement(List<String> list, String id, bool condition) {
    if (condition && !list.contains(id)) {
      list.add(id);
    }
  }
}
