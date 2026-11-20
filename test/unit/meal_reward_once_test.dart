import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/nutrition_gamification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails the first time ranks are worked out, then behaves normally.
class _FlakyGamification extends GamificationService {
  int failuresLeft = 1;

  @override
  Map<String, String> calculateRank() {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('rank lookup failed');
    }
    return super.calculateRank();
  }
}

/// Saves the XP fine, but the nutrition progress save fails the first time.
class _NutritionSaveFails extends NutritionGamificationService {
  int failuresLeft = 1;

  @override
  Future<void> saveNutritionProgress(NutritionProgress progress) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('nutrition progress save failed');
    }
    await super.saveNutritionProgress(progress);
  }
}

/// Fails the first user-progress save; optionally after writing it, like a
/// save that stored the data and then reported an error.
class _UserSaveFails extends NutritionGamificationService {
  _UserSaveFails({this.writeFirst = false});

  final bool writeFirst;
  int failuresLeft = 1;

  @override
  Future<void> saveUserProgress(UserProgress progress) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      if (writeFirst) await super.saveUserProgress(progress);
      throw StateError('user progress save failed');
    }
    await super.saveUserProgress(progress);
  }
}

/// A day where all meals are done and the protein goal is met, so the meal
/// count, the protein-goal count and the streak all change.
DailyNutrition _fullDay([String date = '2026-10-17']) {
  final base = DailyNutrition.defaultForDate(date);
  return base.copyWith(
    meals: [for (final m in base.meals) m.copyWith(isCompleted: true)],
    baseProtein: base.targets.proteinGrams,
  );
}

DailyNutrition _day([String date = '2026-10-17']) =>
    DailyNutrition.defaultForDate(date);

int _xp() => LocalStorage.getUserProgress().totalXP;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FitnessProvider.resetInstance);

  group('processMealCompleted pays each meal slot once a day', () {
    final service = NutritionGamificationService();

    test('the first completion pays 10 XP and counts the meal', () async {
      final before = _xp();
      final result = await service.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: DateTime(2026, 10, 17, 13),
      );

      expect(result.xpEarned, 10);
      expect(_xp() - before, 10);
      expect(result.updatedNutritionProgress.totalMealsCompleted, 1);
      expect(
        result.rewards.where((r) => r.type == RewardType.xpBonus),
        hasLength(1),
      );
    });

    test('completing the same meal again changes nothing', () async {
      final at = DateTime(2026, 10, 17, 13);
      await service.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: at,
      );
      final xp = _xp();
      final nutrition = LocalStorage.getNutritionProgress().toJson();
      final progress = LocalStorage.getUserProgress().toJson();

      final again = await service.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: at.add(const Duration(minutes: 5)),
      );

      expect(again.xpEarned, 0);
      expect(again.rewards, isEmpty);
      expect(again.unlockedBadges, isEmpty);
      expect(_xp(), xp);
      expect(LocalStorage.getUserProgress().toJson(), progress);
      expect(LocalStorage.getNutritionProgress().toJson(), nutrition);
    });

    test('the slot name is not case sensitive', () async {
      final at = DateTime(2026, 10, 17, 13);
      await service.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'Lunch',
        eventDate: at,
      );
      final again = await service.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: at,
      );
      expect(again.xpEarned, 0);
    });

    test('two calls at the same moment pay once', () async {
      final at = DateTime(2026, 10, 17, 13);
      final before = _xp();
      final results = await Future.wait([
        service.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        ),
        service.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        ),
      ]);

      expect(results.map((r) => r.xpEarned).toList()..sort(), [0, 10]);
      expect(_xp() - before, 10);
    });

    test('different meals on the same day each pay', () async {
      final at = DateTime(2026, 10, 17, 13);
      final before = _xp();
      for (final slot in ['breakfast', 'lunch', 'dinner']) {
        final r = await service.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: slot,
          eventDate: at,
        );
        expect(r.xpEarned, 10, reason: slot);
      }
      expect(_xp() - before, 30);
    });

    test('the same meal on another day pays again', () async {
      final before = _xp();
      final day1 = await service.processMealCompleted(
        dailyNutrition: _day('2026-10-17'),
        mealSlot: 'lunch',
        eventDate: DateTime(2026, 10, 17, 23, 59),
      );
      final day2 = await service.processMealCompleted(
        dailyNutrition: _day('2026-10-18'),
        mealSlot: 'lunch',
        eventDate: DateTime(2026, 10, 18, 0, 1),
      );
      expect(day1.xpEarned, 10);
      expect(day2.xpEarned, 10);
      expect(_xp() - before, 20);
    });

    test('a failed attempt can be repeated and pays once', () async {
      final flaky = _FlakyGamification();
      final flakyService = NutritionGamificationService(
        gamificationService: flaky,
      );
      final at = DateTime(2026, 10, 17, 13);
      final before = _xp();

      await expectLater(
        flakyService.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        ),
        throwsA(isA<StateError>()),
      );
      expect(_xp(), before, reason: 'nothing was paid or saved');
      expect(LocalStorage.hasRewardedMeal('2026-10-17|lunch'), isFalse);

      final retry = await flakyService.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: at,
      );
      final again = await flakyService.processMealCompleted(
        dailyNutrition: _day(),
        mealSlot: 'lunch',
        eventDate: at,
      );

      expect(retry.xpEarned, 10);
      expect(again.xpEarned, 0);
      expect(_xp() - before, 10);
    });

    group('the two saves are recoverable', () {
      final at = DateTime(2026, 10, 17, 13);
      const key = '2026-10-17|lunch';

      NutritionProgress storedNutrition() =>
          LocalStorage.getNutritionProgress();

      test('a normal completion records the meal with its key', () async {
        final before = _xp();
        final result = await service.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        );
        expect(result.xpEarned, 10);
        expect(_xp() - before, 10);
        expect(storedNutrition().totalMealsCompleted, 1);
        expect(storedNutrition().appliedMealKeys, [key]);
        expect(LocalStorage.hasRewardedMeal(key), isTrue);
      });

      test('the nutrition save fails before anything is stored: the repeat '
          'processes the meal once', () async {
        final failing = _NutritionSaveFails();
        final before = _xp();

        await expectLater(
          failing.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: at,
          ),
          throwsA(isA<StateError>()),
        );
        expect(_xp(), before, reason: 'no XP was saved');
        expect(storedNutrition().totalMealsCompleted, 0);
        expect(storedNutrition().appliedMealKeys, isEmpty);
        expect(LocalStorage.hasRewardedMeal(key), isFalse);

        final retry = await failing.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        );
        final again = await failing.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        );

        expect(retry.xpEarned, 10);
        expect(again.xpEarned, 0);
        expect(_xp() - before, 10);
        expect(storedNutrition().totalMealsCompleted, 1);
        expect(storedNutrition().appliedMealKeys, [key]);
      });

      test('the nutrition save worked but the XP save failed: the repeat saves '
          'the XP without counting the meal again', () async {
        await LocalStorage.saveNutritionProgress(
          NutritionProgress(
            currentNutritionStreak: 3,
            longestNutritionStreak: 3,
            totalMealsCompleted: 7,
            totalProteinGoalsAchieved: 2,
            lastNutritionDate: DateTime(2026, 10, 16),
          ),
        );
        final failing = _UserSaveFails();
        final before = _xp();

        await expectLater(
          failing.processMealCompleted(
            dailyNutrition: _fullDay(),
            mealSlot: 'lunch',
            eventDate: at,
          ),
          throwsA(isA<StateError>()),
        );
        // Counted and keyed, but no XP yet, and the slot is free again.
        expect(_xp(), before);
        expect(storedNutrition().totalMealsCompleted, 8);
        expect(storedNutrition().totalProteinGoalsAchieved, 3);
        expect(storedNutrition().currentNutritionStreak, 4);
        expect(storedNutrition().appliedMealKeys, [key]);
        expect(LocalStorage.hasRewardedMeal(key), isFalse);

        final retry = await failing.processMealCompleted(
          dailyNutrition: _fullDay(),
          mealSlot: 'lunch',
          eventDate: at,
        );

        // 10 meal + 25 all meals + 50 protein, saved once.
        expect(retry.xpEarned, 85);
        expect(_xp() - before, 85);
        expect(
          storedNutrition().totalMealsCompleted,
          8,
          reason: 'not recounted',
        );
        expect(storedNutrition().totalProteinGoalsAchieved, 3);
        expect(storedNutrition().currentNutritionStreak, 4);
        expect(LocalStorage.getUserProgress().nutritionStreak, 4);

        final third = await failing.processMealCompleted(
          dailyNutrition: _fullDay(),
          mealSlot: 'lunch',
          eventDate: at,
        );
        expect(third.xpEarned, 0);
        expect(_xp() - before, 85);
      });

      test('the XP save stored the data and then reported an error: the slot '
          'stays recorded and nothing is paid twice', () async {
        final failing = _UserSaveFails(writeFirst: true);
        final before = _xp();

        await expectLater(
          failing.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: at,
          ),
          throwsA(isA<StateError>()),
        );
        expect(_xp() - before, 10, reason: 'the write did happen');
        expect(LocalStorage.hasRewardedMeal(key), isTrue);

        final retry = await failing.processMealCompleted(
          dailyNutrition: _day(),
          mealSlot: 'lunch',
          eventDate: at,
        );
        expect(retry.xpEarned, 0);
        expect(_xp() - before, 10);
        expect(storedNutrition().totalMealsCompleted, 1);
        expect(
          LocalStorage.getUserProgress().achievements,
          contains('first_meal'),
        );
      });

      test(
        'first_meal unlocks exactly once across a failure and its repeat',
        () async {
          final failing = _UserSaveFails();

          await expectLater(
            failing.processMealCompleted(
              dailyNutrition: _day(),
              mealSlot: 'lunch',
              eventDate: at,
            ),
            throwsA(isA<StateError>()),
          );
          expect(
            LocalStorage.getUserProgress().achievements,
            isNot(contains('first_meal')),
            reason: 'the failed attempt did not save the achievement',
          );

          final retry = await failing.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: at,
          );
          final again = await failing.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: at,
          );

          expect(retry.unlockedBadges.map((b) => b.id), contains('first_meal'));
          expect(again.unlockedBadges, isEmpty);
          expect(
            LocalStorage.getUserProgress().achievements.where(
              (a) => a == 'first_meal',
            ),
            hasLength(1),
          );
        },
      );

      test(
        'two calls for the same slot at the same moment count it once',
        () async {
          final before = _xp();
          final results = await Future.wait([
            service.processMealCompleted(
              dailyNutrition: _day(),
              mealSlot: 'lunch',
              eventDate: at,
            ),
            service.processMealCompleted(
              dailyNutrition: _day(),
              mealSlot: 'lunch',
              eventDate: at,
            ),
          ]);
          expect(results.map((r) => r.xpEarned).toList()..sort(), [0, 10]);
          expect(_xp() - before, 10);
          expect(storedNutrition().totalMealsCompleted, 1);
          expect(storedNutrition().appliedMealKeys, [key]);
        },
      );

      test('only the newest keys are kept', () async {
        final first = DateTime(2026, 10, 18, 13);
        for (var i = 0; i < 60; i++) {
          await service.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: first.add(Duration(days: i)),
          );
        }
        final keys = storedNutrition().appliedMealKeys;
        expect(keys, hasLength(NutritionProgress.maxAppliedMealKeys));
        expect(keys.last, '2026-12-16|lunch');
        expect(keys, isNot(contains('2026-10-18|lunch')));
        expect(storedNutrition().totalMealsCompleted, 60);
      });

      test(
        'a record saved before this field existed still loads and works',
        () async {
          final legacy = NutritionProgress.fromJson({
            'currentNutritionStreak': 2,
            'longestNutritionStreak': 5,
            'totalMealsCompleted': 11,
            'totalProteinGoalsAchieved': 1,
            'lastNutritionDate': DateTime(2026, 10, 16).toIso8601String(),
          });
          expect(legacy.appliedMealKeys, isEmpty);
          expect(legacy.toJson().containsKey('appliedMealKeys'), isFalse);

          await LocalStorage.saveNutritionProgress(legacy);
          final result = await service.processMealCompleted(
            dailyNutrition: _day(),
            mealSlot: 'lunch',
            eventDate: at,
          );
          expect(result.xpEarned, 10);
          expect(storedNutrition().totalMealsCompleted, 12);
          expect(storedNutrition().appliedMealKeys, [key]);
          expect(storedNutrition().longestNutritionStreak, 5);
        },
      );
    });

    test('without a slot every call pays, as before', () async {
      final before = _xp();
      final a = await service.processMealCompleted(dailyNutrition: _day());
      final b = await service.processMealCompleted(dailyNutrition: _day());
      expect(a.xpEarned, 10);
      expect(b.xpEarned, 10);
      expect(_xp() - before, 20);
    });

    test('old entries are dropped when a new one is added', () async {
      await LocalStorage.markMealRewarded('2025-01-01|lunch');
      expect(LocalStorage.hasRewardedMeal('2025-01-01|lunch'), isTrue);
      final today = DateTime.now().toIso8601String().split('T').first;
      await LocalStorage.markMealRewarded('$today|lunch');
      expect(LocalStorage.hasRewardedMeal('2025-01-01|lunch'), isFalse);
      expect(LocalStorage.hasRewardedMeal('$today|lunch'), isTrue);
    });
  });

  group('through the provider', () {
    test('completing a meal pays 10 XP', () async {
      final provider = FitnessProvider.instance;
      final before = _xp();
      await provider.completeMeal('Lunch');
      expect(_xp() - before, 10);
    });

    test('completing it again pays nothing', () async {
      final provider = FitnessProvider.instance;
      await provider.completeMeal('Lunch');
      final xp = _xp();
      await provider.completeMeal('Lunch');
      await provider.completeMeal('Lunch');
      expect(_xp(), xp);
    });

    test(
      'complete, incomplete, complete pays once and never for incomplete',
      () async {
        final provider = FitnessProvider.instance;
        final before = _xp();

        await provider.completeMeal('Lunch');
        expect(_xp() - before, 10);

        await provider.completeMeal('Lunch', false);
        expect(_xp() - before, 10, reason: 'unticking pays nothing');

        await provider.completeMeal('Lunch');
        expect(_xp() - before, 10, reason: 'ticking it again pays nothing');
        expect(
          provider.todayNutritionLog.meals
              .firstWhere((m) => m.name == 'Lunch')
              .isCompleted,
          isTrue,
        );
      },
    );

    test('the meal id and its name are the same meal', () async {
      final provider = FitnessProvider.instance;
      final before = _xp();
      await provider.completeMeal('meal_lunch');
      await provider.completeMeal('Lunch');
      await provider.completeMeal('lunch');
      expect(_xp() - before, 10);
    });

    test('different meals each pay', () async {
      final provider = FitnessProvider.instance;
      final before = _xp();
      await provider.completeMeal('Breakfast');
      await provider.completeMeal('Lunch');
      await provider.completeMeal('Dinner');
      expect(_xp() - before, 30);
    });

    test(
      'the daily-nutrition toggle and the log share one meal slot',
      () async {
        final provider = FitnessProvider.instance;
        final before = _xp();
        final lunchId = provider.todayNutrition.meals
            .firstWhere((m) => m.name == 'Lunch')
            .id;

        await provider.completeMeal('Lunch');
        await provider.toggleMealCompletion(lunchId); // on
        await provider.toggleMealCompletion(lunchId); // off
        await provider.toggleMealCompletion(lunchId); // on again

        expect(_xp() - before, 10);
      },
    );

    test('ticking a meal on and off through the toggle pays once', () async {
      final provider = FitnessProvider.instance;
      final before = _xp();
      final lunchId = provider.todayNutrition.meals
          .firstWhere((m) => m.name == 'Lunch')
          .id;

      await provider.toggleMealCompletion(lunchId); // on: pays
      await provider.toggleMealCompletion(lunchId); // off
      await provider.toggleMealCompletion(lunchId); // on again

      expect(_xp() - before, 10);
    });

    test(
      'the nutrition streak and counts are not advanced by repeats',
      () async {
        final provider = FitnessProvider.instance;
        await provider.completeMeal('Lunch');
        final after = LocalStorage.getNutritionProgress().toJson();
        await provider.completeMeal('Lunch', false);
        await provider.completeMeal('Lunch');
        expect(LocalStorage.getNutritionProgress().toJson(), after);
      },
    );
  });
}
