import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../models/nutrition_progress.dart';
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
      id: 'nutrition_master',
      title: 'Nutrition Master',
      description:
          'Reached daily nutrition and macro targets consistently.',
      iconCodePoint: Icons.restaurant_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Rare',
    ),
    AchievementBadge(
      id: 'personal_record',
      title: 'Personal Record',
      description:
          'Achieved a new personal best on key compound lifts!',
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
      description: 'Maintained a 30-day nutrition streak! Phenomenal dedication.',
      iconCodePoint: Icons.workspace_premium_rounded.codePoint,
      category: 'Nutrition',
      rarity: 'Legendary',
    ),
  ];

  /// Get master list of all available achievements
  static List<AchievementBadge> get allAchievements => _allAchievements;

  /// Evaluates progress metrics and returns newly unlocked badges along with updated UserProgress
  static AchievementEvaluationResult evaluateAchievements(
    UserProgress progress, {
    NutritionProgress? nutritionProgress,
    bool hasNutritionGoalAchieved = false,
    bool hasNewPersonalRecord = false,
  }) {
    final List<String> existingAchievements = List.from(progress.achievements);
    final List<AchievementBadge> newlyUnlocked = [];

    final now = DateTime.now();

    for (final badge in _allAchievements) {
      if (existingAchievements.contains(badge.id)) {
        continue; // Already unlocked
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
        case 'nutrition_master':
          shouldUnlock = hasNutritionGoalAchieved;
          break;
        case 'personal_record':
          shouldUnlock = hasNewPersonalRecord;
          break;
        case 'first_meal':
          shouldUnlock =
              (nutritionProgress != null && nutritionProgress.totalMealsCompleted >= 1);
          break;
        case 'meals_10':
          shouldUnlock =
              (nutritionProgress != null && nutritionProgress.totalMealsCompleted >= 10);
          break;
        case 'protein_master':
          shouldUnlock = hasNutritionGoalAchieved ||
              (nutritionProgress != null && nutritionProgress.totalProteinGoalsAchieved >= 1);
          break;
        case 'nutrition_streak_7':
          shouldUnlock = (nutritionProgress != null &&
                  nutritionProgress.currentNutritionStreak >= 7) ||
              progress.nutritionStreak >= 7;
          break;
        case 'nutrition_streak_30':
          shouldUnlock = (nutritionProgress != null &&
                  nutritionProgress.currentNutritionStreak >= 30) ||
              progress.nutritionStreak >= 30;
          break;
      }

      if (shouldUnlock) {
        existingAchievements.add(badge.id);
        newlyUnlocked.add(badge.copyWith(
          earnedDate: now,
          isUnlocked: true,
        ));
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
