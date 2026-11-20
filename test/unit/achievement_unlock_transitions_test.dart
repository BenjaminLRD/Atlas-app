import 'package:atlas/app_theme.dart';
import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/services/achievement_service.dart';
import 'package:atlas/widgets/dashboard/dashboard_achievements_card.dart';
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

UserProgress _progress({
  int workouts = 0,
  int streak = 0,
  List<String> achievements = const [],
}) => UserProgress(
  totalXP: 0,
  completedWorkouts: workouts,
  rankedUnlocked: false,
  currentRank: 'Unranked',
  currentDivision: 'Unranked',
  workoutStreak: streak,
  longestStreak: streak,
  totalWorkoutMinutes: 0,
  totalVolumeLifted: 0,
  achievements: achievements,
);

List<String> _ids(AchievementEvaluationResult r) =>
    r.newlyUnlockedBadges.map((b) => b.id).toList();

Set<String> _rewardIds(Iterable<RewardEvent> rewards) => rewards
    .where((r) => r.type == RewardType.achievement)
    .map((r) => r.id)
    .toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FitnessProvider.resetInstance);

  group('the evaluator tells what is newly unlocked', () {
    // What the workout flow produces for a first workout: it has already saved
    // first_workout before the evaluator looks.
    UserProgress afterFirstWorkout({bool pr = false}) =>
        GamificationService().progressAfterWorkout(
          _workout(pr: pr),
          _progress(),
          streakAfterWorkout: 1,
        );

    test('a badge saved by the workout flow is newly unlocked once', () {
      final progress = afterFirstWorkout();
      expect(progress.achievements, contains('first_workout'));

      final result = AchievementService.evaluateAchievements(
        progress,
        previousAchievements: const [],
      );

      expect(_ids(result), ['first_workout']);
      // The id was already saved: it is not added a second time.
      expect(
        result.updatedProgress.achievements.where((a) => a == 'first_workout'),
        hasLength(1),
      );
    });

    test('evaluating again with what is now earned unlocks nothing', () {
      final first = AchievementService.evaluateAchievements(
        afterFirstWorkout(),
        previousAchievements: const [],
      );
      final again = AchievementService.evaluateAchievements(
        first.updatedProgress,
        previousAchievements: first.updatedProgress.achievements,
      );
      expect(_ids(again), isEmpty);
      expect(
        again.updatedProgress.achievements,
        first.updatedProgress.achievements,
      );
    });

    test('without a previous list it behaves as before', () {
      // Already saved means already earned.
      final result = AchievementService.evaluateAchievements(
        afterFirstWorkout(),
      );
      expect(_ids(result), isEmpty);
    });

    test('a badge earned in an earlier workout is not rewarded again', () {
      final earlier = _progress(workouts: 2, achievements: ['first_workout']);
      final next = GamificationService().progressAfterWorkout(
        _workout(),
        earlier,
        streakAfterWorkout: 1,
      );
      final result = AchievementService.evaluateAchievements(
        next,
        previousAchievements: earlier.achievements,
      );
      expect(_ids(result), isNot(contains('first_workout')));
    });

    test('the seventh day streak and the hundredth workout are announced', () {
      final before = _progress(workouts: 99, streak: 6);
      final after = GamificationService().progressAfterWorkout(
        _workout(),
        before,
        streakAfterWorkout: 7,
      );
      final result = AchievementService.evaluateAchievements(
        after,
        previousAchievements: before.achievements,
      );
      expect(_ids(result), containsAll(['streak_7', 'workouts_100']));
    });

    test('a saved id whose rule is not met is not announced', () {
      final result = AchievementService.evaluateAchievements(
        _progress(workouts: 1, streak: 3, achievements: ['streak_7']),
        previousAchievements: const [],
      );
      expect(_ids(result), isNot(contains('streak_7')));
    });

    test('milestones the evaluator has no rule for are not announced', () {
      final result = AchievementService.evaluateAchievements(
        _progress(
          workouts: 25,
          streak: 30,
          achievements: [
            'workout_5',
            'workout_25',
            'streak_30',
            'ranked_unlocked',
          ],
        ),
        previousAchievements: const [],
      );
      expect(
        _ids(result),
        isNot(
          anyOf(
            contains('workout_5'),
            contains('workout_25'),
            contains('streak_30'),
            contains('ranked_unlocked'),
          ),
        ),
      );
    });

    test('a first personal record is announced once, under its catalog id', () {
      final progress = afterFirstWorkout(pr: true);
      expect(progress.achievements, contains('first_pr'));

      final result = AchievementService.evaluateAchievements(
        progress,
        hasNewPersonalRecord: true,
        previousAchievements: const [],
      );
      expect(_ids(result), contains('personal_record'));
      final saved = result.updatedProgress.achievements;
      expect(saved.where((a) => a == 'personal_record'), hasLength(1));
      expect(saved.where((a) => a == 'first_pr'), hasLength(1));
    });

    test('a personal record earned under the old id is not rewarded again', () {
      final saved = ['first_workout', 'first_pr'];
      final result = AchievementService.evaluateAchievements(
        _progress(workouts: 3, achievements: saved),
        hasNewPersonalRecord: true,
        previousAchievements: saved,
      );
      expect(_ids(result), isEmpty);
      // Nothing was added or renamed in the saved list.
      expect(result.updatedProgress.achievements, [
        'first_workout',
        'first_pr',
      ]);
    });

    test('unknown saved ids are left alone and announce nothing', () {
      final result = AchievementService.evaluateAchievements(
        _progress(achievements: ['mystery']),
        previousAchievements: const ['mystery'],
      );
      expect(_ids(result), isEmpty);
      expect(result.updatedProgress.achievements, ['mystery']);
    });
  });

  group('completing workouts', () {
    test(
      'the first workout raises the unlock reward, and no XP with it',
      () async {
        final provider = FitnessProvider.instance;
        final xpBefore = provider.userProgress.totalXP;

        final result = await provider.saveWorkoutCompletion(_workout());

        expect(
          result.unlockedBadges.map((b) => b.id),
          contains('first_workout'),
        );
        expect(
          _rewardIds(result.rewards),
          contains('achievement_first_workout'),
        );
        // The unlock reward carries no XP: the XP added is the workout's (and
        // any challenge bonus), all of it counted in the result.
        expect(
          LocalStorage.getUserProgress().totalXP - xpBefore,
          result.xpEarned,
        );
        expect(
          LocalStorage.getUserProgress().achievements.where(
            (a) => a == 'first_workout',
          ),
          hasLength(1),
        );
      },
    );

    test('the second workout does not raise it again', () async {
      final provider = FitnessProvider.instance;
      await provider.saveWorkoutCompletion(
        _workout(at: DateTime.now().subtract(const Duration(days: 1))),
      );
      final second = await provider.saveWorkoutCompletion(_workout());

      expect(
        second.unlockedBadges.map((b) => b.id),
        isNot(contains('first_workout')),
      );
      expect(
        _rewardIds(second.rewards),
        isNot(contains('achievement_first_workout')),
      );
    });

    test('submitting the same workout again changes nothing', () async {
      final provider = FitnessProvider.instance;
      final entry = _workout();
      final first = await provider.saveWorkoutCompletion(entry);
      final saved = List<String>.of(
        LocalStorage.getUserProgress().achievements,
      );
      final xp = LocalStorage.getUserProgress().totalXP;

      final repeat = await provider.saveWorkoutCompletion(entry);

      expect(first.unlockedBadges, isNotEmpty);
      expect(repeat.isDuplicate, isTrue);
      expect(repeat.unlockedBadges, isEmpty);
      expect(LocalStorage.getUserProgress().achievements, saved);
      expect(LocalStorage.getUserProgress().totalXP, xp);
    });

    test('a retry after an interruption raises the reward once', () async {
      final provider = FitnessProvider.instance;
      provider.rewardStageHook = (stage) async {
        if (stage == 'beforeProgressSave') throw StateError('stopped');
      };
      final entry = _workout();
      await expectLater(
        provider.saveWorkoutCompletion(entry),
        throwsA(isA<StateError>()),
      );
      // Nothing was saved, so nothing was announced yet.
      expect(LocalStorage.getUserProgress().achievements, isEmpty);

      provider.rewardStageHook = null;
      final retry = await provider.saveWorkoutCompletion(entry);

      expect(
        retry.unlockedBadges.where((b) => b.id == 'first_workout'),
        hasLength(1),
      );
      expect(
        LocalStorage.getUserProgress().achievements.where(
          (a) => a == 'first_workout',
        ),
        hasLength(1),
      );
    });

    test('the seventh day in a row raises the 7 day streak reward', () async {
      await LocalStorage.saveWorkoutHistory([
        for (var i = 1; i <= 6; i++)
          _workout(at: DateTime.now().subtract(Duration(days: i))),
      ]);
      await LocalStorage.saveUserProgress(
        _progress(workouts: 6, streak: 6, achievements: ['first_workout']),
      );
      final provider = FitnessProvider.instance..refreshAll();

      final result = await provider.saveWorkoutCompletion(_workout());

      expect(result.unlockedBadges.map((b) => b.id), contains('streak_7'));
      expect(
        result.unlockedBadges.map((b) => b.id),
        isNot(contains('first_workout')),
        reason: 'earned long ago',
      );
    });

    test('a first personal record is announced once across workouts', () async {
      final provider = FitnessProvider.instance;
      final first = await provider.saveWorkoutCompletion(
        _workout(
          pr: true,
          at: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final second = await provider.saveWorkoutCompletion(_workout(pr: true));

      expect(
        first.unlockedBadges.map((b) => b.id),
        contains('personal_record'),
      );
      expect(
        second.unlockedBadges.map((b) => b.id),
        isNot(contains('personal_record')),
      );
      final saved = LocalStorage.getUserProgress().achievements;
      expect(saved.toSet().length, saved.length);
    });
  });

  group('DashboardAchievementsCard count', () {
    Future<void> pumpCard(WidgetTester tester, List<String> saved) async {
      await LocalStorage.saveWorkoutHistory([_workout()]);
      await LocalStorage.saveUserProgress(
        _progress(workouts: 1, achievements: saved),
      );
      FitnessProvider.instance.refreshAll();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: DashboardAchievementsCard()),
        ),
      );
      await tester.pump();
    }

    String earned(int n) =>
        'You\'ve earned $n achievement milestones! Keep pushing toward your goals.';

    setUp(() async {
      await ShowcaseModeProvider.instance.disableShowcaseMode();
    });

    testWidgets('an alias and its catalog id count once', (tester) async {
      final saved = ['first_pr', 'personal_record', 'first_workout'];
      await pumpCard(tester, saved);
      expect(find.text(earned(2)), findsOneWidget);
      // Reading it did not change what is saved.
      expect(LocalStorage.getUserProgress().achievements, saved);
    });

    testWidgets('catalog ids each count once', (tester) async {
      await pumpCard(tester, ['first_workout', 'streak_7', 'workout_5']);
      expect(find.text(earned(3)), findsOneWidget);
    });

    testWidgets('unknown ids do not inflate the count', (tester) async {
      await pumpCard(tester, ['first_workout', 'mystery', '', 'another']);
      expect(find.text(earned(1)), findsOneWidget);
    });

    testWidgets('only unknown ids show the encouragement, not a zero', (
      tester,
    ) async {
      await pumpCard(tester, ['mystery']);
      expect(find.text('Keep it up!'), findsOneWidget);
      expect(find.textContaining('earned'), findsNothing);
    });

    testWidgets('an empty list shows the encouragement', (tester) async {
      await pumpCard(tester, const []);
      expect(find.text('Keep it up!'), findsOneWidget);
    });
  });

  group('earnedCount', () {
    test('counts catalog achievements once', () {
      expect(AchievementService.earnedCount(const []), 0);
      expect(
        AchievementService.earnedCount(['first_pr', 'personal_record']),
        1,
      );
      expect(
        AchievementService.earnedCount(['nutrition_goal', 'nutrition_master']),
        1,
      );
      expect(AchievementService.earnedCount(['mystery', 'first_workout']), 1);
    });
  });
}
