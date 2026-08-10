import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/daily_nutrition.dart';
import 'package:aizawl_gym/models/macro_target.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_progress.dart';
import 'package:aizawl_gym/models/user_progress.dart';
import 'package:aizawl_gym/services/achievement_service.dart';
import 'package:aizawl_gym/services/nutrition_gamification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NutritionProgress Model Tests', () {
    test('initial NutritionProgress has default zero values', () {
      final progress = NutritionProgress.initial();
      expect(progress.currentNutritionStreak, equals(0));
      expect(progress.longestNutritionStreak, equals(0));
      expect(progress.totalMealsCompleted, equals(0));
      expect(progress.totalProteinGoalsAchieved, equals(0));
      expect(progress.lastNutritionDate, isNull);
    });

    test('updateStreak increments streak on consecutive days', () {
      final day1 = DateTime(2026, 8, 1);
      final day2 = DateTime(2026, 8, 2);

      var progress = NutritionProgress.initial().updateStreak(day1);
      expect(progress.currentNutritionStreak, equals(1));
      expect(progress.longestNutritionStreak, equals(1));

      progress = progress.updateStreak(day2);
      expect(progress.currentNutritionStreak, equals(2));
      expect(progress.longestNutritionStreak, equals(2));
    });

    test('updateStreak maintains streak count on same day', () {
      final day1Time1 = DateTime(2026, 8, 1, 8, 0);
      final day1Time2 = DateTime(2026, 8, 1, 13, 0);

      var progress = NutritionProgress.initial().updateStreak(day1Time1);
      expect(progress.currentNutritionStreak, equals(1));

      progress = progress.updateStreak(day1Time2);
      expect(progress.currentNutritionStreak, equals(1));
    });

    test('updateStreak resets current streak to 1 after gap > 1 day while preserving longest', () {
      final day1 = DateTime(2026, 8, 1);
      final day2 = DateTime(2026, 8, 2);
      final day5 = DateTime(2026, 8, 5); // 3 day gap

      var progress = NutritionProgress.initial().updateStreak(day1);
      progress = progress.updateStreak(day2);
      expect(progress.currentNutritionStreak, equals(2));

      progress = progress.updateStreak(day5);
      expect(progress.currentNutritionStreak, equals(1));
      expect(progress.longestNutritionStreak, equals(2));
    });

    test('toJson and fromJson work symmetrically', () {
      final progress = NutritionProgress(
        currentNutritionStreak: 5,
        longestNutritionStreak: 12,
        totalMealsCompleted: 45,
        totalProteinGoalsAchieved: 10,
        lastNutritionDate: DateTime(2026, 8, 5),
      );

      final json = progress.toJson();
      final restored = NutritionProgress.fromJson(json);

      expect(restored.currentNutritionStreak, equals(5));
      expect(restored.longestNutritionStreak, equals(12));
      expect(restored.totalMealsCompleted, equals(45));
      expect(restored.totalProteinGoalsAchieved, equals(10));
      expect(restored.lastNutritionDate, equals(DateTime(2026, 8, 5)));
    });
  });

  group('NutritionGamificationService Event & XP Tests', () {
    late NutritionGamificationService service;

    setUp(() {
      service = NutritionGamificationService();
    });

    test('meal completed awards +10 XP and increments totalMealsCompleted', () async {
      final daily = DailyNutrition(
        date: '2026-08-01',
        baseCalories: 500,
        baseProtein: 20,
        baseCarbs: 60,
        baseFat: 15,
        targets: const MacroTarget(calories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60),
        meals: [
          MealEntry(id: 'm1', mealType: MealCategory.breakfast, isCompleted: true),
          MealEntry(id: 'm2', mealType: MealCategory.lunch, isCompleted: false),
        ],
      );

      final result = await service.processMealCompleted(
        dailyNutrition: daily,
        eventDate: DateTime(2026, 8, 1),
      );

      expect(result.xpEarned, equals(10));
      expect(result.updatedUserProgress.totalXP, equals(10));
      expect(result.updatedNutritionProgress.totalMealsCompleted, equals(1));
    });

    test('daily nutrition completed awards bonus +25 XP when all meals completed', () async {
      final daily = DailyNutrition(
        date: '2026-08-01',
        baseCalories: 1800,
        baseProtein: 100, // Below protein goal
        baseCarbs: 200,
        baseFat: 50,
        targets: const MacroTarget(calories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60),
        meals: [
          MealEntry(id: 'm1', mealType: MealCategory.breakfast, isCompleted: true),
          MealEntry(id: 'm2', mealType: MealCategory.lunch, isCompleted: true),
        ],
      );

      final result = await service.processMealCompleted(
        dailyNutrition: daily,
        eventDate: DateTime(2026, 8, 1),
      );

      // Meal completed (+10) + Daily nutrition completed (+25) = 35 XP
      expect(result.xpEarned, equals(35));
      expect(result.updatedUserProgress.totalXP, equals(35));
    });

    test('protein goal achieved awards +50 XP and updates streak', () async {
      final daily = DailyNutrition(
        date: '2026-08-01',
        baseCalories: 2100,
        baseProtein: 160, // Exceeds 150g goal
        baseCarbs: 200,
        baseFat: 60,
        targets: const MacroTarget(calories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60),
        meals: [
          MealEntry(id: 'm1', mealType: MealCategory.breakfast, isCompleted: true),
          MealEntry(id: 'm2', mealType: MealCategory.lunch, isCompleted: false),
        ],
      );

      final result = await service.processMealCompleted(
        dailyNutrition: daily,
        eventDate: DateTime(2026, 8, 1),
      );

      // Meal (+10) + Protein Goal (+50) = 60 XP
      expect(result.xpEarned, equals(60));
      expect(result.updatedNutritionProgress.totalProteinGoalsAchieved, equals(1));
      expect(result.updatedNutritionProgress.currentNutritionStreak, equals(1));
      expect(result.updatedUserProgress.nutritionStreak, equals(1));
    });
  });

  group('AchievementService Nutrition Badges Tests', () {
    test('unlocks first_meal badge on first meal completed', () {
      final progress = UserProgress.initial();
      final nutritionProgress = NutritionProgress.initial().copyWith(totalMealsCompleted: 1);

      final result = AchievementService.evaluateAchievements(
        progress,
        nutritionProgress: nutritionProgress,
      );

      expect(result.updatedProgress.achievements, contains('first_meal'));
      expect(result.newlyUnlockedBadges.any((b) => b.id == 'first_meal'), isTrue);
    });

    test('unlocks meals_10 badge on 10 meals completed', () {
      final progress = UserProgress.initial();
      final nutritionProgress = NutritionProgress.initial().copyWith(totalMealsCompleted: 10);

      final result = AchievementService.evaluateAchievements(
        progress,
        nutritionProgress: nutritionProgress,
      );

      expect(result.updatedProgress.achievements, contains('meals_10'));
      expect(result.newlyUnlockedBadges.any((b) => b.id == 'meals_10'), isTrue);
    });

    test('unlocks protein_master badge when protein goal achieved', () {
      final progress = UserProgress.initial();
      final nutritionProgress = NutritionProgress.initial().copyWith(totalProteinGoalsAchieved: 1);

      final result = AchievementService.evaluateAchievements(
        progress,
        nutritionProgress: nutritionProgress,
        hasNutritionGoalAchieved: true,
      );

      expect(result.updatedProgress.achievements, contains('protein_master'));
      expect(result.newlyUnlockedBadges.any((b) => b.id == 'protein_master'), isTrue);
    });

    test('unlocks 7-day and 30-day nutrition streak badges', () {
      final progress = UserProgress.initial();
      final nutritionProgress7 = NutritionProgress.initial().copyWith(currentNutritionStreak: 7);

      final result7 = AchievementService.evaluateAchievements(
        progress,
        nutritionProgress: nutritionProgress7,
      );
      expect(result7.updatedProgress.achievements, contains('nutrition_streak_7'));

      final nutritionProgress30 = NutritionProgress.initial().copyWith(currentNutritionStreak: 30);
      final result30 = AchievementService.evaluateAchievements(
        progress,
        nutritionProgress: nutritionProgress30,
      );
      expect(result30.updatedProgress.achievements, contains('nutrition_streak_30'));
    });
  });
}
