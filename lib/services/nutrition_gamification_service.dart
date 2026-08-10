import '../data/gamification_service.dart';
import '../data/local_storage.dart';
import '../models/badge.dart';
import '../models/daily_nutrition.dart';
import '../models/nutrition_progress.dart';
import '../models/reward_event.dart';
import '../models/user_progress.dart';
import '../widgets/common/rank_up_dialog.dart';
import 'achievement_service.dart';

/// Result object containing updated UserProgress, NutritionProgress,
/// total earned XP, newly unlocked badges, and generated RewardEvents.
class NutritionGamificationResult {
  final UserProgress updatedUserProgress;
  final NutritionProgress updatedNutritionProgress;
  final int xpEarned;
  final List<AchievementBadge> unlockedBadges;
  final List<RewardEvent> rewards;

  const NutritionGamificationResult({
    required this.updatedUserProgress,
    required this.updatedNutritionProgress,
    required this.xpEarned,
    this.unlockedBadges = const [],
    this.rewards = const [],
  });
}

/// Service responsible for evaluating nutrition events, awarding XP rewards,
/// managing nutrition streaks, updating rank progression, and unlocking achievements.
class NutritionGamificationService {
  final GamificationService _gamificationService;

  NutritionGamificationService({GamificationService? gamificationService})
      : _gamificationService = gamificationService ?? GamificationService();

  /// Retrieve current NutritionProgress state from LocalStorage
  NutritionProgress getNutritionProgress() {
    return LocalStorage.getNutritionProgress();
  }

  /// Persist NutritionProgress state to LocalStorage
  Future<void> saveNutritionProgress(NutritionProgress progress) async {
    await LocalStorage.saveNutritionProgress(progress);
  }

  /// Evaluates a single meal completion event.
  /// Rewards:
  /// - +10 XP for meal completed
  /// - +25 XP if all planned meals for the day are completed (Daily Nutrition Completed)
  /// - +50 XP if daily protein goal is reached (Protein Goal Achieved)
  /// - Updates Nutrition Streak if qualifying.
  Future<NutritionGamificationResult> processMealCompleted({
    required DailyNutrition dailyNutrition,
    UserProgress? currentProgress,
    NutritionProgress? currentNutritionProgress,
    DateTime? eventDate,
  }) async {
    final UserProgress userProgress =
        currentProgress ?? LocalStorage.getUserProgress();
    final NutritionProgress nutritionProgress =
        currentNutritionProgress ?? getNutritionProgress();
    final DateTime now = eventDate ?? DateTime.now();

    int xpEarned = 0;
    final List<RewardEvent> rewards = [];

    // 1. Meal Completed (+10 XP)
    xpEarned += 10;
    final int newTotalMeals = nutritionProgress.totalMealsCompleted + 1;

    // 2. Daily Nutrition Completed (+25 XP)
    final bool isAllMealsCompleted = dailyNutrition.meals.isNotEmpty &&
        dailyNutrition.meals.every((m) => m.isCompleted);
    if (isAllMealsCompleted) {
      xpEarned += 25;
    }

    // 3. Protein Goal Achieved (+50 XP)
    final bool isProteinGoalAchieved =
        dailyNutrition.totalProteinConsumed >= dailyNutrition.targets.proteinGrams;
    int newProteinGoalsCount = nutritionProgress.totalProteinGoalsAchieved;
    if (isProteinGoalAchieved) {
      xpEarned += 50;
      newProteinGoalsCount += 1;
    }

    // 4. Nutrition Streak tracking
    NutritionProgress updatedNutritionProgress = nutritionProgress.copyWith(
      totalMealsCompleted: newTotalMeals,
      totalProteinGoalsAchieved: newProteinGoalsCount,
    );

    final bool isQualifyingDay = isProteinGoalAchieved || isAllMealsCompleted;
    if (isQualifyingDay) {
      updatedNutritionProgress = updatedNutritionProgress.updateStreak(now);
    }

    // 5. Update XP and Ranks
    final String prevRank = userProgress.fullRank;
    final int newTotalXP = userProgress.totalXP + xpEarned;
    final bool isUnlocked =
        _gamificationService.checkRankUnlock(userProgress.completedWorkouts);
    final Map<String, String> rankMap =
        _gamificationService.calculateRankFromXP(newTotalXP, isUnlocked);

    final UserProgress interimUserProgress = userProgress.copyWith(
      totalXP: newTotalXP,
      rankedUnlocked: isUnlocked,
      currentRank: rankMap['tier']!,
      currentDivision: rankMap['division']!,
      nutritionStreak: updatedNutritionProgress.currentNutritionStreak,
    );

    // 6. Evaluate Achievements
    final evalResult = AchievementService.evaluateAchievements(
      interimUserProgress,
      nutritionProgress: updatedNutritionProgress,
      hasNutritionGoalAchieved: isProteinGoalAchieved,
    );

    final UserProgress finalUserProgress = evalResult.updatedProgress;

    // 7. Save updated states to LocalStorage
    await LocalStorage.saveUserProgress(finalUserProgress);
    await saveNutritionProgress(updatedNutritionProgress);

    // 8. Generate RewardEvents for presentation
    final String newRank = finalUserProgress.fullRank;
    if (prevRank != newRank) {
      final rankUp = RankUpDetails(
        previousRank: prevRank,
        newRank: newRank,
        xpGained: xpEarned,
        message: 'Your nutrition consistency unlocked a new competitive tier!',
      );
      rewards.add(RewardEvent.rankUp(rankUp));
    }

    for (final badge in evalResult.newlyUnlockedBadges) {
      rewards.add(RewardEvent.achievement(badge));
    }

    if (xpEarned > 0) {
      rewards.add(RewardEvent.xpBonus(
        amount: xpEarned,
        source: 'Meal Completion',
      ));
    }

    return NutritionGamificationResult(
      updatedUserProgress: finalUserProgress,
      updatedNutritionProgress: updatedNutritionProgress,
      xpEarned: xpEarned,
      unlockedBadges: evalResult.newlyUnlockedBadges,
      rewards: rewards,
    );
  }

  /// Evaluates overall DailyNutrition updates (e.g. when logging food items or saving daily targets).
  /// Checks for protein goal achievement and daily meal completion bonus and streak updates.
  Future<NutritionGamificationResult> processDailyNutrition({
    required DailyNutrition dailyNutrition,
    UserProgress? currentProgress,
    NutritionProgress? currentNutritionProgress,
    DateTime? eventDate,
  }) async {
    final UserProgress userProgress =
        currentProgress ?? LocalStorage.getUserProgress();
    final NutritionProgress nutritionProgress =
        currentNutritionProgress ?? getNutritionProgress();
    final DateTime now = eventDate ?? DateTime.now();

    int xpEarned = 0;
    final List<RewardEvent> rewards = [];

    final bool isAllMealsCompleted = dailyNutrition.meals.isNotEmpty &&
        dailyNutrition.meals.every((m) => m.isCompleted);
    final bool isProteinGoalAchieved =
        dailyNutrition.totalProteinConsumed >= dailyNutrition.targets.proteinGrams;

    if (isAllMealsCompleted) {
      xpEarned += 25;
    }
    if (isProteinGoalAchieved) {
      xpEarned += 50;
    }

    NutritionProgress updatedNutritionProgress = nutritionProgress;
    if (isProteinGoalAchieved &&
        nutritionProgress.totalProteinGoalsAchieved == 0) {
      updatedNutritionProgress = updatedNutritionProgress.copyWith(
        totalProteinGoalsAchieved: nutritionProgress.totalProteinGoalsAchieved + 1,
      );
    }

    final bool isQualifyingDay = isProteinGoalAchieved || isAllMealsCompleted;
    if (isQualifyingDay) {
      updatedNutritionProgress = updatedNutritionProgress.updateStreak(now);
    }

    final String prevRank = userProgress.fullRank;
    final int newTotalXP = userProgress.totalXP + xpEarned;
    final bool isUnlocked =
        _gamificationService.checkRankUnlock(userProgress.completedWorkouts);
    final Map<String, String> rankMap =
        _gamificationService.calculateRankFromXP(newTotalXP, isUnlocked);

    final UserProgress interimUserProgress = userProgress.copyWith(
      totalXP: newTotalXP,
      rankedUnlocked: isUnlocked,
      currentRank: rankMap['tier']!,
      currentDivision: rankMap['division']!,
      nutritionStreak: updatedNutritionProgress.currentNutritionStreak,
    );

    final evalResult = AchievementService.evaluateAchievements(
      interimUserProgress,
      nutritionProgress: updatedNutritionProgress,
      hasNutritionGoalAchieved: isProteinGoalAchieved,
    );

    final UserProgress finalUserProgress = evalResult.updatedProgress;

    await LocalStorage.saveUserProgress(finalUserProgress);
    await saveNutritionProgress(updatedNutritionProgress);

    final String newRank = finalUserProgress.fullRank;
    if (prevRank != newRank) {
      final rankUp = RankUpDetails(
        previousRank: prevRank,
        newRank: newRank,
        xpGained: xpEarned,
        message: 'Your nutrition consistency unlocked a new competitive tier!',
      );
      rewards.add(RewardEvent.rankUp(rankUp));
    }

    for (final badge in evalResult.newlyUnlockedBadges) {
      rewards.add(RewardEvent.achievement(badge));
    }

    if (xpEarned > 0) {
      rewards.add(RewardEvent.xpBonus(
        amount: xpEarned,
        source: 'Nutrition Goals Achieved',
      ));
    }

    return NutritionGamificationResult(
      updatedUserProgress: finalUserProgress,
      updatedNutritionProgress: updatedNutritionProgress,
      xpEarned: xpEarned,
      unlockedBadges: evalResult.newlyUnlockedBadges,
      rewards: rewards,
    );
  }
}
