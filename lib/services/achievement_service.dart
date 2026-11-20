import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../models/nutrition_progress.dart';
import '../models/progress_analytics.dart';
import '../models/user_progress.dart';

/// Result object holding updated UserProgress and list of newly unlocked badges
class AchievementEvaluationResult {
  final UserProgress updatedProgress;
  final List<AchievementBadge> newlyUnlockedBadges;

  const AchievementEvaluationResult({
    required this.updatedProgress,
    required this.newlyUnlockedBadges,
  });
}

/// Service responsible for evaluating UserProgress milestone criteria
/// and unlocking achievement badges.
class AchievementService {
  static AchievementService? _instance;
  static AchievementService get instance => _instance ??= AchievementService();

  /// Returns all defined system achievement badges
  static List<AchievementBadge> getAllAchievements() => _allAchievements;

  /// Registry of all earnable system achievements
  static final List<AchievementBadge> _allAchievements = [
    AchievementBadge(
      id: 'first_workout',
      title: 'First Workout',
      description:
          'Completed your very first training session! The journey begins.',
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Common',
    ),
    // The next four are awarded by the workout flow (GamificationService) and
    // are saved in the athlete's progress, so they have catalog entries to be
    // recognised and shown. Their rules live there, not in evaluateAchievements.
    AchievementBadge(
      id: 'workout_5',
      title: '5 Workouts',
      description: 'Completed 5 training sessions. The habit is forming!',
      iconCodePoint: Icons.directions_run_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Common',
    ),
    AchievementBadge(
      id: 'ranked_unlocked',
      title: 'Ranked Unlocked',
      description: 'Completed 5 workouts and unlocked Ranked mode.',
      iconCodePoint: Icons.military_tech_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'workouts_10',
      title: 'First 10 Workouts',
      description:
          'Completed your first 10 training sessions. Building momentum!',
      iconCodePoint: Icons.celebration_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Common',
    ),
    AchievementBadge(
      id: 'workout_25',
      title: '25 Workouts',
      description: 'Completed 25 training sessions. Consistency is paying off!',
      iconCodePoint: Icons.emoji_events_outlined.codePoint,
      category: 'Milestone',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'workouts_100',
      title: 'Century Lifter',
      description:
          'Completed 100 workouts! You are an absolute legend of consistency.',
      iconCodePoint: Icons.workspace_premium_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Legendary',
    ),
    AchievementBadge(
      id: 'streak_7',
      title: '7 Day Streak',
      description:
          'Keep the fire alive! Complete workouts for 7 consecutive days.',
      iconCodePoint: Icons.local_fire_department_rounded.codePoint,
      category: 'Consistency',
      rarity: 'Epic',
    ),
    AchievementBadge(
      id: 'streak_10',
      title: '10 Day Streak',
      description: 'Maintained a 10-day workout streak! Unstoppable momentum.',
      iconCodePoint: Icons.whatshot_rounded.codePoint,
      category: 'Consistency',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'streak_14',
      title: '14 Day Streak',
      description: 'Maintained a 14-day workout streak! Iron discipline.',
      iconCodePoint: Icons.local_fire_department_rounded.codePoint,
      category: 'Consistency',
      rarity: 'Epic',
    ),
    AchievementBadge(
      id: 'streak_30',
      title: '30 Day Streak',
      description: 'Maintained a 30-day workout streak! Elite discipline.',
      iconCodePoint: Icons.whatshot_rounded.codePoint,
      category: 'Consistency',
      rarity: 'Legendary',
    ),
    AchievementBadge(
      id: 'bench_100kg',
      title: 'First 100kg Bench Press',
      description:
          'Pressed 100kg or more on the bench press! Elite upper body power.',
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      category: 'Strength',
      rarity: 'Legendary',
    ),
    AchievementBadge(
      id: 'volume_100k',
      title: '100,000kg Total Volume',
      description:
          'Lifted over 100,000kg total mechanical volume across all sessions!',
      iconCodePoint: Icons.layers_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Epic',
    ),
    AchievementBadge(
      id: 'volume_500k',
      title: 'Half Million Club',
      description:
          'Lifted 500,000kg total volume! Exceptional heavyweight mastery.',
      iconCodePoint: Icons.stars_rounded.codePoint,
      category: 'Milestone',
      rarity: 'Legendary',
    ),
    AchievementBadge(
      id: 'strength_increase_20kg',
      title: '+20kg Strength Increase',
      description:
          'Increased strength by 20kg or more on a key compound movement!',
      iconCodePoint: Icons.trending_up_rounded.codePoint,
      category: 'Strength',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'consistency_90',
      title: '90% Consistency',
      description:
          'Maintained 90%+ workout schedule consistency over a 4-week span.',
      iconCodePoint: Icons.verified_rounded.codePoint,
      category: 'Consistency',
      rarity: 'Epic',
    ),
    AchievementBadge(
      id: 'nutrition_master',
      title: 'Nutrition Master',
      description: 'Reached daily nutrition and macro targets consistently.',
      iconCodePoint: Icons.restaurant_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'personal_record',
      title: 'Personal Record',
      description: 'Achieved a new personal best on key compound lifts!',
      iconCodePoint: Icons.emoji_events_rounded.codePoint,
      category: 'Strength',
      rarity: 'Legendary',
    ),
    AchievementBadge(
      id: 'first_meal',
      title: 'First Meal Logged',
      description: 'Logged your very first meal! Fueling for gains.',
      iconCodePoint: Icons.restaurant_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Common',
    ),
    AchievementBadge(
      id: 'meals_10',
      title: '10 Meals Completed',
      description: 'Completed 10 planned meals. Consistency in nutrition!',
      iconCodePoint: Icons.rice_bowl_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Common',
    ),
    AchievementBadge(
      id: 'protein_master',
      title: 'Protein Master',
      description: 'Achieved daily protein goal.',
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'nutrition_streak_7',
      title: '7 Day Nutrition Streak',
      description: 'Maintained a 7-day nutrition streak!',
      iconCodePoint: Icons.local_fire_department_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Epic',
    ),
    AchievementBadge(
      id: 'nutrition_streak_30',
      title: '30 Day Nutrition Streak',
      description:
          'Maintained a 30-day nutrition streak! Phenomenal dedication.',
      iconCodePoint: Icons.workspace_premium_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Legendary',
    ),
  ];

  /// Get master list of all available achievements
  static List<AchievementBadge> get allAchievements => _allAchievements;

  /// Ids that older versions saved for an achievement which has another id in
  /// the catalog. Both ids can be saved for the same achievement (the workout
  /// flow and the catalog each award their own), so they count as one.
  static const Map<String, String> legacyAliases = {
    'first_pr': 'personal_record',
    'nutrition_goal': 'nutrition_master',
  };

  /// How many different catalog achievements the saved ids stand for. An id
  /// and its legacy alias count once; ids the catalog does not know do not
  /// count.
  static int earnedCount(Iterable<String> savedIds) =>
      unlockedCatalogIds(savedIds).length;

  /// The catalog ids covered by the achievement ids saved in a progress.
  /// Legacy aliases are mapped to their catalog id; ids that match nothing in
  /// the catalog are ignored. Nothing is changed in the saved list.
  static Set<String> unlockedCatalogIds(Iterable<String> savedIds) {
    final catalog = {for (final b in _allAchievements) b.id};
    return {
      for (final id in savedIds)
        if (catalog.contains(legacyAliases[id] ?? id)) legacyAliases[id] ?? id,
    };
  }

  /// Evaluates progress metrics and returns newly unlocked badges along with updated UserProgress
  static AchievementEvaluationResult evaluateAchievements(
    UserProgress progress, {
    NutritionProgress? nutritionProgress,
    AthleteAnalyticsReport? athleteAnalytics,
    bool hasNutritionGoalAchieved = false,
    bool hasNewPersonalRecord = false,
    List<String>? previousAchievements,
  }) {
    final List<String> existingAchievements = List.from(progress.achievements);
    final List<AchievementBadge> newlyUnlocked = [];

    final now = DateTime.now();

    // What was already earned before this update. By default that is what the
    // progress holds. A caller that has already added ids to the progress
    // (the workout flow saves its own ids first) passes the list from before,
    // so a badge saved during this update still counts as newly unlocked.
    // Then legacy aliases count as the badge they stand for, so an
    // achievement earned under an old id is not rewarded a second time.
    final earnedBefore = previousAchievements == null
        ? null
        : unlockedCatalogIds(previousAchievements);

    for (final badge in _allAchievements) {
      final alreadySaved = existingAchievements.contains(badge.id);
      final wasEarnedBefore = earnedBefore == null
          ? alreadySaved
          : earnedBefore.contains(badge.id);
      if (wasEarnedBefore) {
        continue; // Earned before: never rewarded again
      }

      bool shouldUnlock = false;

      switch (badge.id) {
        case 'first_workout':
          shouldUnlock = progress.completedWorkouts >= 1;
          break;
        case 'workouts_10':
          shouldUnlock = progress.completedWorkouts >= 10;
          break;
        case 'workouts_100':
          shouldUnlock = progress.completedWorkouts >= 100;
          break;
        case 'streak_7':
          shouldUnlock = progress.workoutStreak >= 7;
          break;
        case 'streak_10':
          shouldUnlock = progress.workoutStreak >= 10;
          break;
        case 'streak_14':
          shouldUnlock = progress.workoutStreak >= 14;
          break;
        case 'bench_100kg':
          if (athleteAnalytics != null) {
            shouldUnlock = athleteAnalytics.strengthProgressions.any(
              (s) =>
                  s.exerciseName.toLowerCase().contains('bench') &&
                  (s.currentWeight >= 100.0 || s.estimatedOneRepMax >= 100.0),
            );
          }
          break;
        case 'volume_100k':
          final totalVol = athleteAnalytics?.currentSnapshot.totalVolume ?? 0.0;
          shouldUnlock = totalVol >= 100000.0;
          break;
        case 'volume_500k':
          final totalVol = athleteAnalytics?.currentSnapshot.totalVolume ?? 0.0;
          shouldUnlock = totalVol >= 500000.0;
          break;
        case 'strength_increase_20kg':
          if (athleteAnalytics != null) {
            shouldUnlock = athleteAnalytics.strengthProgressions.any(
              (s) => s.improvement >= 20.0,
            );
          }
          break;
        case 'consistency_90':
          if (athleteAnalytics != null) {
            shouldUnlock = athleteAnalytics.consistencyPercentage >= 90.0;
          }
          break;
        case 'nutrition_master':
          shouldUnlock = hasNutritionGoalAchieved;
          break;
        case 'personal_record':
          shouldUnlock = hasNewPersonalRecord;
          break;
        case 'first_meal':
          shouldUnlock =
              (nutritionProgress != null &&
              nutritionProgress.totalMealsCompleted >= 1);
          break;
        case 'meals_10':
          shouldUnlock =
              (nutritionProgress != null &&
              nutritionProgress.totalMealsCompleted >= 10);
          break;
        case 'protein_master':
          shouldUnlock =
              hasNutritionGoalAchieved ||
              (nutritionProgress != null &&
                  nutritionProgress.totalProteinGoalsAchieved >= 1);
          break;
        case 'nutrition_streak_7':
          shouldUnlock =
              (nutritionProgress != null &&
                  nutritionProgress.currentNutritionStreak >= 7) ||
              progress.nutritionStreak >= 7;
          break;
        case 'nutrition_streak_30':
          shouldUnlock =
              (nutritionProgress != null &&
                  nutritionProgress.currentNutritionStreak >= 30) ||
              progress.nutritionStreak >= 30;
          break;
      }

      if (shouldUnlock) {
        if (!alreadySaved) existingAchievements.add(badge.id);
        newlyUnlocked.add(badge.copyWith(earnedDate: now, isUnlocked: true));
      }
    }

    final updatedProgress = progress.copyWith(
      achievements: existingAchievements,
    );

    return AchievementEvaluationResult(
      updatedProgress: updatedProgress,
      newlyUnlockedBadges: newlyUnlocked,
    );
  }
}
