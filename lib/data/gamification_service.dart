import '../models/daily_nutrition.dart';
import '../models/user_progress.dart';
import '../models/workout_history.dart';
import 'local_storage.dart';
import '../services/gamification/workout_xp_calculator.dart';
import '../services/ranked/rank_ladder.dart';
import '../services/ranked/ranked_progress_store.dart';

/// Gamification service: XP, levels, streaks and achievements.
///
/// Rank (tier and division) is not XP-based: it comes from Ranked milestones
/// verified by the server (see `services/ranked/`). This service only reads
/// the cached rank so progress objects show the same rank everywhere.
class GamificationService {
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
    final rankData = calculateRank();

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

  /// 2. Current rank from Ranked milestones (the same on every screen).
  Map<String, String> calculateRank() {
    final position = RankedProgressStore.position;
    if (!position.isRanked) {
      return {
        'tier': 'Unranked',
        'division': 'Unranked',
        'fullRank': 'Unranked',
      };
    }
    return {
      'tier': position.tier,
      'division': position.division,
      'fullRank': position.title,
    };
  }

  /// 3. What the next division takes: one more milestone level.
  ///
  /// Everything returned comes from one rank position, so the current rank,
  /// the next rank and the progress always agree. That position is the rank
  /// verified by Ranked milestones; when there is none (for example the
  /// Showcase athlete, whose rank is demo data), [fallback] is used.
  Map<String, dynamic> getNextRankRequirement({RankPosition? fallback}) {
    final stored = RankedProgressStore.position;
    final position = stored.isRanked
        ? stored
        : (fallback ?? const RankPosition.unranked());
    final next = position.isRanked ? position.next : RankLadder.fromPoints(1);
    final topPoints = RankLadder.divisionCount;
    return {
      'currentRank': position.title,
      'nextRank': next?.title ?? 'Max Rank Reached',
      'isMaxRank': position.isTop,
      'neededMilestones': next == null
          ? 0
          : RankLadder.pointsForIndex(next.index) - position.points,
      'points': position.points,
      'topPoints': topPoints,
      'progressPercentage': (position.points / topPoints).clamp(0.0, 1.0),
    };
  }

  /// 4. Workout XP Award Engine
  /// Applies the XP from [WorkoutXpCalculator] to the progress.
  ///
  /// [streakAfterWorkout] is the streak including this workout. When the
  /// caller already knows it (the completion flow calculates it from the
  /// history) it passes it in; otherwise it is the stored streak plus one.
  Future<UserProgress> awardWorkoutXP(
    WorkoutHistory workout, [
    UserProgress? currentProgress,
    int? streakAfterWorkout,
  ]) async {
    final updatedProgress = progressAfterWorkout(
      workout,
      currentProgress ?? getProgress(),
      streakAfterWorkout: streakAfterWorkout,
    );
    await saveProgress(updatedProgress);
    return updatedProgress;
  }

  /// The progress after [workout], without saving it. The completion flow
  /// uses this so the rewards can be saved together with its own bookkeeping
  /// in one write.
  UserProgress progressAfterWorkout(
    WorkoutHistory workout,
    UserProgress current, {
    int? streakAfterWorkout,
  }) {
    final int newCompletedWorkouts = current.completedWorkouts + 1;
    final bool isUnlocked = checkRankUnlock(newCompletedWorkouts);
    final int durationMins = (workout.durationSeconds / 60).ceil();

    final int newStreak = streakAfterWorkout ?? current.workoutStreak + 1;
    final int newLongestStreak = newStreak > current.longestStreak
        ? newStreak
        : current.longestStreak;

    final int xpReward = WorkoutXpCalculator.forWorkout(
      completionPercentage: workout.completionPercentage,
      hasPersonalRecord: workout.personalRecords.isNotEmpty,
      streakAfterWorkout: newStreak,
    ).total;

    final int newTotalXP = current.totalXP + xpReward;
    final Map<String, String> rankMap = calculateRank();

    // Update achievements
    final List<String> updatedAchievements = List<String>.from(
      current.achievements,
    );
    _checkAchievement(
      updatedAchievements,
      'first_workout',
      newCompletedWorkouts >= 1,
    );
    _checkAchievement(updatedAchievements, 'ranked_unlocked', isUnlocked);
    _checkAchievement(
      updatedAchievements,
      'workout_5',
      newCompletedWorkouts >= 5,
    );
    _checkAchievement(
      updatedAchievements,
      'workout_25',
      newCompletedWorkouts >= 25,
    );
    _checkAchievement(
      updatedAchievements,
      'workouts_100',
      newCompletedWorkouts >= 100,
    );
    _checkAchievement(updatedAchievements, 'streak_7', newStreak >= 7);
    _checkAchievement(updatedAchievements, 'streak_30', newStreak >= 30);
    _checkAchievement(
      updatedAchievements,
      'first_pr',
      workout.personalRecords.isNotEmpty,
    );

    final UserProgress updatedProgress = current.copyWith(
      totalXP: newTotalXP,
      completedWorkouts: newCompletedWorkouts,
      rankedUnlocked: isUnlocked,
      currentRank: rankMap['tier']!,
      currentDivision: rankMap['division']!,
      workoutStreak: newStreak,
      longestStreak: newLongestStreak,
      totalWorkoutMinutes: current.totalWorkoutMinutes + durationMins,
      totalVolumeLifted:
          current.totalVolumeLifted + (workout.exercisesCompleted * 500.0),
      achievements: updatedAchievements,
    );

    return updatedProgress;
  }

  /// Alias method for backward compatibility
  Future<UserProgress> processWorkoutCompleted(WorkoutHistory workout) async {
    return awardWorkoutXP(workout);
  }

  /// Process XP reward for nutrition goals achieved
  Future<UserProgress> processNutritionGoalAchieved(
    DailyNutrition nutrition,
  ) async {
    final current = getProgress();

    final caloriesMet =
        nutrition.totalCaloriesConsumed >= (nutrition.targets.calories * 0.9);
    final proteinMet =
        nutrition.totalProteinConsumed >=
        (nutrition.targets.proteinGrams * 0.9);

    if (!caloriesMet || !proteinMet) {
      return current;
    }

    const rewardXP = 50;
    final newXP = current.totalXP + rewardXP;
    final isUnlocked = checkRankUnlock(current.completedWorkouts);
    final rankMap = calculateRank();

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
