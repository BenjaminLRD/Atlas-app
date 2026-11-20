import 'package:atlas/app_theme.dart';
import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/mock_badges.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/ranked_screen.dart';
import 'package:atlas/services/achievement_service.dart';
import 'package:atlas/widgets/common/achievement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutHistory _workout({bool pr = false, DateTime? at}) => WorkoutHistory(
  workoutName: 'Push Day',
  dateCompleted: at ?? DateTime.now(),
  durationSeconds: 2400,
  exercisesCompleted: 4,
  completionPercentage: 100,
  personalRecords: pr ? const ['Bench PR'] : const [],
);

final _catalogIds = AchievementService.allAchievements.map((b) => b.id).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FitnessProvider.resetInstance);

  group('every achievement the workout flow awards has a catalog entry', () {
    test('the ids awarded at all the thresholds', () {
      // A progress one workout short of every milestone, finishing a workout
      // with a personal record.
      const nearlyThere = UserProgress(
        totalXP: 0,
        completedWorkouts: 99,
        rankedUnlocked: false,
        currentRank: 'Unranked',
        currentDivision: 'Unranked',
        workoutStreak: 29,
        longestStreak: 29,
        totalWorkoutMinutes: 0,
        totalVolumeLifted: 0,
        achievements: [],
      );
      final after = GamificationService().progressAfterWorkout(
        _workout(pr: true),
        nearlyThere,
        streakAfterWorkout: 30,
      );

      expect(
        after.achievements,
        containsAll(<String>[
          'first_workout',
          'ranked_unlocked',
          'workout_5',
          'workout_25',
          'workouts_100',
          'streak_7',
          'streak_30',
          'first_pr',
        ]),
      );
      for (final id in after.achievements) {
        expect(
          AchievementService.unlockedCatalogIds([id]),
          hasLength(1),
          reason: '"$id" is awarded but not recognised by the catalog',
        );
      }
    });

    test('the id awarded for a met nutrition goal', () async {
      final day = DailyNutrition(
        date: '2026-10-17',
        targets: const MacroTarget(
          calories: 2000,
          proteinGrams: 150,
          carbsGrams: 200,
          fatGrams: 60,
        ),
        meals: const [],
        baseCalories: 2000,
        baseProtein: 150,
      );
      final progress = await GamificationService().processNutritionGoalAchieved(
        day,
      );
      expect(progress.achievements, contains('nutrition_goal'));
      expect(AchievementService.unlockedCatalogIds(['nutrition_goal']), {
        'nutrition_master',
      });
    });

    test('the catalog ids the evaluator awards are all in the catalog', () {
      final result = AchievementService.evaluateAchievements(
        const UserProgress(
          totalXP: 0,
          completedWorkouts: 100,
          rankedUnlocked: true,
          currentRank: 'Unranked',
          currentDivision: 'Unranked',
          workoutStreak: 14,
          longestStreak: 14,
          totalWorkoutMinutes: 0,
          totalVolumeLifted: 0,
          achievements: [],
        ),
        hasNewPersonalRecord: true,
      );
      expect(result.updatedProgress.achievements, isNotEmpty);
      for (final id in result.updatedProgress.achievements) {
        expect(_catalogIds, contains(id));
      }
    });

    test('catalog ids are unique', () {
      expect(_catalogIds.length, AchievementService.allAchievements.length);
    });
  });

  group('saved ids and the catalog', () {
    test('legacy aliases lead to a catalog entry of their own', () {
      for (final entry in AchievementService.legacyAliases.entries) {
        expect(_catalogIds, contains(entry.value), reason: entry.key);
        expect(_catalogIds, isNot(contains(entry.key)), reason: entry.key);
      }
    });

    test('an alias and its catalog id count as one achievement', () {
      expect(
        AchievementService.unlockedCatalogIds(['first_pr', 'personal_record']),
        {'personal_record'},
      );
    });

    test('unknown or empty ids are ignored', () {
      expect(
        AchievementService.unlockedCatalogIds([
          'mystery',
          '',
          'FIRST_WORKOUT',
          'first_workout',
        ]),
        {'first_workout'},
      );
      expect(AchievementService.unlockedCatalogIds(const []), isEmpty);
    });

    test('the saved list is never changed by reading it', () {
      final saved = ['first_pr', 'mystery', 'workout_5'];
      AchievementService.unlockedCatalogIds(saved);
      BadgeService(unlockedAchievementIds: () => saved).getAllBadges();
      expect(saved, ['first_pr', 'mystery', 'workout_5']);
    });

    test(
      'BadgeService shows legacy ids and the new milestones as unlocked',
      () {
        final service = BadgeService(
          unlockedAchievementIds: () => const [
            'first_pr',
            'workout_5',
            'streak_30',
            'ranked_unlocked',
            'mystery',
          ],
        );
        final unlocked = service
            .getAllBadges()
            .where((b) => b.isUnlocked)
            .map((b) => b.id)
            .toSet();
        expect(unlocked, {
          'personal_record',
          'workout_5',
          'streak_30',
          'ranked_unlocked',
        });
      },
    );

    test(
      'only unknown ids unlock nothing and do not fall back to a preview',
      () {
        final service = BadgeService(
          unlockedAchievementIds: () => const ['mystery'],
        );
        expect(service.getRecentBadges(), isEmpty);
        expect(service.getAllBadges().where((b) => b.isUnlocked), isEmpty);
      },
    );
  });

  group('completing workouts', () {
    test('repeated completion does not duplicate any achievement', () async {
      final provider = FitnessProvider.instance;
      for (var day = 3; day >= 0; day--) {
        await provider.saveWorkoutCompletion(
          _workout(
            pr: day.isEven,
            at: DateTime.now().subtract(Duration(days: day)),
          ),
        );
      }
      final saved = LocalStorage.getUserProgress().achievements;

      expect(saved.toSet().length, saved.length, reason: 'no id twice');
      expect(saved, containsAll(['first_workout', 'first_pr']));
      for (final id in saved) {
        expect(
          AchievementService.unlockedCatalogIds([id]),
          hasLength(1),
          reason: '"$id" awarded by a real completion is not in the catalog',
        );
      }
    });

    test('a completed workout is shown by the badge list', () async {
      final provider = FitnessProvider.instance;
      await provider.saveWorkoutCompletion(_workout(pr: true));

      final shown = BadgeService(
        unlockedAchievementIds: () => provider.userProgress.achievements,
      ).getAllBadges().where((b) => b.isUnlocked).map((b) => b.id).toSet();

      expect(shown, containsAll(['first_workout', 'personal_record']));
    });
  });

  group('screens', () {
    final otherErrors = <FlutterErrorDetails>[];

    Future<void> setView(WidgetTester tester) async {
      otherErrors.clear();
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) {
          otherErrors.add(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('ranked screen shows a milestone saved under its old id', (
      tester,
    ) async {
      await LocalStorage.saveUserProgress(
        UserProgress.initial().copyWith(
          achievements: ['first_pr', 'workout_5'],
        ),
      );
      FitnessProvider.instance.refreshAll();
      await setView(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const RankedScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Personal Record'), findsWidgets);
      expect(find.text('5 Workouts'), findsWidgets);
      expect(otherErrors, isEmpty);
    });

    Future<void> pumpGallery(WidgetTester tester, List<String> ids) async {
      await setView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementGallery(unlockedBadgeIds: ids),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the gallery counts a legacy id as its catalog badge', (
      tester,
    ) async {
      // first_pr is the old id of Personal Record; workout_5 is a milestone;
      // "mystery" is nothing.
      await pumpGallery(tester, ['first_pr', 'workout_5', 'mystery']);

      expect(find.text('2 of ${_catalogIds.length} Badges'), findsOneWidget);
      expect(otherErrors, isEmpty);
    });

    testWidgets('the gallery counts an alias and its catalog id once', (
      tester,
    ) async {
      await pumpGallery(tester, ['first_pr', 'personal_record']);

      expect(find.text('1 of ${_catalogIds.length} Badges'), findsOneWidget);
    });
  });
}
