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
  ///
  /// [mealSlot] names the meal that was completed (for example `lunch`). With
  /// it, a meal pays once per day: completing the same slot again that day, or
  /// ticking it off and on, changes nothing and returns no rewards. The slot is
  /// recorded before anything is saved.
  ///
  /// The nutrition progress (meal count, streak) is saved first, together with
  /// the meal's key, and the XP and achievements after it. If the XP save does
  /// not happen, the slot is taken back and the repeat pays the XP without
  /// counting the meal or advancing the streak again, because the key is
  /// already saved. If it cannot be told whether the XP was saved (the save
  /// threw, but the stored XP is the new value or cannot be read), the slot
  /// stays recorded: the XP can not be paid twice. Without a slot, every call
  /// pays, as before.
  Future<NutritionGamificationResult> processMealCompleted({
    required DailyNutrition dailyNutrition,
    UserProgress? currentProgress,
    NutritionProgress? currentNutritionProgress,
    DateTime? eventDate,
    String? mealSlot,
  }) async {
    final UserProgress userProgress =
        currentProgress ?? LocalStorage.getUserProgress();
    final NutritionProgress nutritionProgress =
        currentNutritionProgress ?? getNutritionProgress();
    final DateTime now = eventDate ?? DateTime.now();

    String? rewardKey;
    if (mealSlot != null) {
      final day = now.toIso8601String().split('T').first;
      rewardKey = '$day|${mealSlot.toLowerCase()}';
      if (LocalStorage.hasRewardedMeal(rewardKey)) {
        return NutritionGamificationResult(
          updatedUserProgress: userProgress,
          updatedNutritionProgress: nutritionProgress,
          xpEarned: 0,
        );
      }
      // Recorded before the first await, so a second call at the same moment
      // sees it.
      await LocalStorage.markMealRewarded(rewardKey);
    }

    int? xpSaveExpectedTotal; // set when the XP save is about to start
    try {
      return await _rewardMealCompleted(
        dailyNutrition: dailyNutrition,
        userProgress: userProgress,
        nutritionProgress: nutritionProgress,
        now: now,
        mealKey: rewardKey,
        onXpSaveStarting: (total) => xpSaveExpectedTotal = total,
      );
    } catch (_) {
      // Taken back only when it is certain the XP was not saved. A save that
      // threw may still have written, so look at what is stored.
      if (rewardKey != null && !_xpMayBeSaved(xpSaveExpectedTotal)) {
        await LocalStorage.unmarkMealRewarded(rewardKey);
      }
      rethrow;
    }
  }

  /// Whether the XP of this attempt may be in storage. [expectedTotal] is the
  /// XP total the attempt was saving; null means the XP save never started.
  /// If storage cannot be read it counts as "may be saved", the safe answer
  /// against paying twice.
  bool _xpMayBeSaved(int? expectedTotal) {
    if (expectedTotal == null) return false;
    try {
      return LocalStorage.getUserProgress().totalXP == expectedTotal;
    } catch (_) {
      return true;
    }
  }

  /// Saves the XP and achievements (user progress) of a meal completion.
  /// Separate so a test can make it fail.
  Future<void> saveUserProgress(UserProgress progress) async {
    await LocalStorage.saveUserProgress(progress);
  }

  Future<NutritionGamificationResult> _rewardMealCompleted({
    required DailyNutrition dailyNutrition,
    required UserProgress userProgress,
    required NutritionProgress nutritionProgress,
    required DateTime now,
    required String? mealKey,
    required void Function(int expectedTotalXp) onXpSaveStarting,
  }) async {
    int xpEarned = 0;
    final List<RewardEvent> rewards = [];

    // The meal was already counted (and the streak advanced) by an earlier
    // attempt whose XP save did not happen: only the XP is still to do.
    final bool alreadyCounted =
        mealKey != null && nutritionProgress.appliedMealKeys.contains(mealKey);

    // 1. Meal Completed (+10 XP)
    xpEarned += 10;
    final int newTotalMeals = nutritionProgress.totalMealsCompleted + 1;

    // 2. Daily Nutrition Completed (+25 XP)
    final bool isAllMealsCompleted =
        dailyNutrition.meals.isNotEmpty &&
        dailyNutrition.meals.every((m) => m.isCompleted);
    if (isAllMealsCompleted) {
      xpEarned += 25;
    }

    // 3. Protein Goal Achieved (+50 XP)
    final bool isProteinGoalAchieved =
        dailyNutrition.totalProteinConsumed >=
        dailyNutrition.targets.proteinGrams;
    int newProteinGoalsCount = nutritionProgress.totalProteinGoalsAchieved;
    if (isProteinGoalAchieved) {
      xpEarned += 50;
      newProteinGoalsCount += 1;
    }

    // 4. Nutrition Streak tracking
    NutritionProgress updatedNutritionProgress = nutritionProgress;
    if (!alreadyCounted) {
      updatedNutritionProgress = nutritionProgress.copyWith(
        totalMealsCompleted: newTotalMeals,
        totalProteinGoalsAchieved: newProteinGoalsCount,
      );

      final bool isQualifyingDay = isProteinGoalAchieved || isAllMealsCompleted;
      if (isQualifyingDay) {
        updatedNutritionProgress = updatedNutritionProgress.updateStreak(now);
      }
      if (mealKey != null) {
        updatedNutritionProgress = updatedNutritionProgress.withAppliedMealKey(
          mealKey,
        );
      }
    }

    // 5. Update XP and Ranks
    final String prevRank = userProgress.fullRank;
    final int newTotalXP = userProgress.totalXP + xpEarned;
    final bool isUnlocked = _gamificationService.checkRankUnlock(
      userProgress.completedWorkouts,
    );
    final Map<String, String> rankMap = _gamificationService.calculateRank();

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

    // 7. Save updated states to LocalStorage. The nutrition progress goes
    // first, with the meal's key in the same write; the XP follows.
    if (!alreadyCounted) {
      await saveNutritionProgress(updatedNutritionProgress);
    }
    onXpSaveStarting(finalUserProgress.totalXP);
    await saveUserProgress(finalUserProgress);

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
      rewards.add(
        RewardEvent.xpBonus(amount: xpEarned, source: 'Meal Completion'),
      );
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

    final bool isAllMealsCompleted =
        dailyNutrition.meals.isNotEmpty &&
        dailyNutrition.meals.every((m) => m.isCompleted);
    final bool isProteinGoalAchieved =
        dailyNutrition.totalProteinConsumed >=
        dailyNutrition.targets.proteinGrams;

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
        totalProteinGoalsAchieved:
            nutritionProgress.totalProteinGoalsAchieved + 1,
      );
    }

    final bool isQualifyingDay = isProteinGoalAchieved || isAllMealsCompleted;
    if (isQualifyingDay) {
      updatedNutritionProgress = updatedNutritionProgress.updateStreak(now);
    }

    final String prevRank = userProgress.fullRank;
    final int newTotalXP = userProgress.totalXP + xpEarned;
    final bool isUnlocked = _gamificationService.checkRankUnlock(
      userProgress.completedWorkouts,
    );
    final Map<String, String> rankMap = _gamificationService.calculateRank();

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
      rewards.add(
        RewardEvent.xpBonus(
          amount: xpEarned,
          source: 'Nutrition Goals Achieved',
        ),
      );
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
