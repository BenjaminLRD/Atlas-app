import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/challenge_service.dart';
import 'package:atlas/services/gamification/workout_xp_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  String id = 'sess_1',
  String workoutId = 'w_push',
  DateTime? start,
  List<String> prs = const [],
}) {
  final startTime =
      start ?? DateTime.now().subtract(const Duration(minutes: 45));
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: 'Push Day',
    startTime: startTime,
    endTime: startTime.add(const Duration(minutes: 45)),
    exercises: const [
      WorkoutSessionExercise(
        id: 'bench',
        name: 'Bench Press',
        muscleGroup: 'Chest',
        sets: [
          WorkoutSessionSet(
            setNumber: 1,
            weight: 60,
            reps: 10,
            completed: true,
          ),
        ],
        isCompleted: true,
      ),
    ],
    completedExercises: 1,
    totalVolume: 600,
    caloriesBurned: 250,
    duration: const Duration(minutes: 45),
    personalRecords: prs,
  );
}

/// XP from weekly challenges completed by this workout (separate bonus).
int _challengeXp(WorkoutCompletionResult result) => result.rewards
    .where((r) => r.type == RewardType.weeklyChallenge)
    .fold(0, (sum, r) => sum + (r.data.xpReward as int));

double _consistencyProgress() => ChallengeService.instance
    .getChallenges()
    .firstWhere((c) => c.id == 'weekly_consistency_5')
    .currentProgress;

CardioSession _cardio({int seconds = 1800}) => CardioSession(
  id: 'cardio_1',
  exerciseId: 'run',
  exerciseName: 'Run',
  category: 'Running',
  durationSeconds: seconds,
  distanceKm: 5,
  caloriesBurned: 300,
  startTime: DateTime.now().subtract(Duration(seconds: seconds)),
  endTime: DateTime.now(),
  metValue: 9,
  isCompleted: true,
);

ActivityRecord _activity() => ActivityRecord(
  id: 'act_cardio_1',
  date: DateTime.now(),
  steps: 6500,
  activeMinutes: 30,
  caloriesBurned: 300,
  distanceKm: 5,
  type: ActivityType.cardio,
  title: 'Run',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.instance.refreshAll();
  });

  tearDown(() async {
    FitnessProvider.instance.rewardStageHook = null;
    await LocalStorage.setShowcaseModeEnabled(false);
    await FitnessProvider.instance.onShowcaseModeToggled(false);
  });

  /// Stops the completion right after [stage], the way a crash would.
  void interruptAfter(String stage) {
    FitnessProvider.instance.rewardStageHook = (s) async {
      if (s == stage) throw StateError('interrupted after $stage');
    };
  }

  group('an interrupted workout still gets its rewards, once', () {
    for (final stage in [
      'recordSaved',
      'challengesApplied',
      'beforeProgressSave',
    ]) {
      test('stopped after $stage, then submitted again', () async {
        final provider = FitnessProvider.instance;
        final session = _session();
        final xpBefore = provider.userProgress.totalXP;
        final workoutsBefore = provider.userProgress.completedWorkouts;
        final challengeBefore = _consistencyProgress();

        interruptAfter(stage);
        await expectLater(
          provider.saveWorkoutCompletion(
            session.toWorkoutHistory(),
            session: session,
          ),
          throwsA(isA<StateError>()),
        );
        // The workout is saved; its rewards are not yet.
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));
        expect(
          LocalStorage.getUserProgress().completedWorkouts,
          workoutsBefore,
        );
        expect(LocalStorage.getPendingWorkoutRewards(), isNotEmpty);

        // The app restarts and the athlete submits the workout again.
        provider.rewardStageHook = null;
        provider.refreshAll();
        final retry = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );

        expect(retry.isDuplicate, isFalse);
        final progress = LocalStorage.getUserProgress();
        expect(progress.completedWorkouts, workoutsBefore + 1);
        expect(progress.totalXP - xpBefore, greaterThanOrEqualTo(125));
        expect(progress.workoutStreak, 1);
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));
        expect(LocalStorage.getWorkoutSessions(), hasLength(1));
        expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
        // The weekly challenge counted this workout once.
        expect(_consistencyProgress() - challengeBefore, 1);
        // The XP the record shows is the XP the calculator gives.
        expect(LocalStorage.getWorkoutHistory().single.xpEarned, 125);
      });
    }

    test('the retry awards exactly what an uninterrupted run awards', () async {
      final provider = FitnessProvider.instance;
      final session = _session();

      final before = provider.userProgress.totalXP;
      final first = await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );
      // Workout XP only: a completed weekly challenge adds its own bonus.
      final uninterrupted =
          provider.userProgress.totalXP - before - _challengeXp(first);
      expect(uninterrupted, greaterThanOrEqualTo(125));

      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      provider.refreshAll();
      final before2 = provider.userProgress.totalXP;
      interruptAfter('beforeProgressSave');
      await expectLater(
        provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        ),
        throwsA(isA<StateError>()),
      );
      // The challenge outcome was noted before the stop.
      final noted = LocalStorage.getPendingWorkoutRewards().values.single;
      expect(noted['challengesApplied'], isTrue);
      final bonus = (noted['challengeBonusXp'] as num).toInt();

      provider.rewardStageHook = null;
      await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );
      expect(provider.userProgress.totalXP - before2 - bonus, uninterrupted);
    });

    test(
      'stopped after the progress was saved: nothing is awarded again',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session();
        final before = provider.userProgress.totalXP;

        interruptAfter('rewardsApplied');
        await expectLater(
          provider.saveWorkoutCompletion(
            session.toWorkoutHistory(),
            session: session,
          ),
          throwsA(isA<StateError>()),
        );
        final xpAfterFirst = LocalStorage.getUserProgress().totalXP;
        expect(xpAfterFirst - before, greaterThanOrEqualTo(125));

        provider.rewardStageHook = null;
        provider.refreshAll();
        final retry = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );
        expect(retry.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xpAfterFirst);
      },
    );

    test(
      'stopped after saving the progress but before clearing the note',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session();
        await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );
        final xp = LocalStorage.getUserProgress().totalXP;
        final workouts = LocalStorage.getUserProgress().completedWorkouts;

        // Put the note back, as if the app stopped just before removing it.
        final saved = LocalStorage.getWorkoutHistory().single;
        await LocalStorage.savePendingWorkoutReward(
          'session|${session.workoutId}|${session.startTime.millisecondsSinceEpoch}',
          {'entry': saved.toJson()},
        );

        final retry = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );
        expect(retry.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xp);
        expect(LocalStorage.getUserProgress().completedWorkouts, workouts);
        expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
      },
    );

    test('the session was saved but the history entry was not', () async {
      final provider = FitnessProvider.instance;
      final session = _session().copyWith(xpEarned: 125);
      final before = provider.userProgress.totalXP;
      await LocalStorage.saveWorkoutSession(session);
      await LocalStorage.savePendingWorkoutReward(
        'session|${session.workoutId}|${session.startTime.millisecondsSinceEpoch}',
        {'entry': session.toWorkoutHistory().toJson()},
      );
      expect(LocalStorage.getWorkoutHistory(), isEmpty);

      await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );

      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(LocalStorage.getWorkoutSessions(), hasLength(1));
      expect(provider.userProgress.totalXP - before, greaterThanOrEqualTo(125));
    });

    test('two retries at the same moment reward once', () async {
      final provider = FitnessProvider.instance;
      final session = _session();
      final before = provider.userProgress.totalXP;

      interruptAfter('recordSaved');
      await expectLater(
        provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        ),
        throwsA(isA<StateError>()),
      );
      provider.rewardStageHook = null;
      provider.refreshAll();

      final results = await Future.wait([
        provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        ),
        provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        ),
      ]);
      expect(identical(results[0], results[1]), isTrue);
      expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      expect(
        LocalStorage.getUserProgress().totalXP - before,
        results[0].xpEarned,
      );
    });

    test(
      'a workout recorded before this change is still a duplicate',
      () async {
        // A record with no note and no applied key: it was rewarded long ago.
        final provider = FitnessProvider.instance;
        final session = _session();
        await LocalStorage.saveWorkoutSession(session);
        await LocalStorage.saveWorkoutCompletion(session.toWorkoutHistory());
        final xp = LocalStorage.getUserProgress().totalXP;

        final result = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );
        expect(result.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xp);
      },
    );
  });

  group('progress keeps its format', () {
    test('old stored progress without the new field still loads', () {
      final json = UserProgress.initial().toJson()
        ..remove('appliedWorkoutKeys');
      final progress = UserProgress.fromJson(json);
      expect(progress.appliedWorkoutKeys, isEmpty);
      expect(progress.toJson()['appliedWorkoutKeys'], isEmpty);
    });

    test('only the most recent applied keys are kept', () async {
      final provider = FitnessProvider.instance;
      for (var i = 0; i < 55; i++) {
        final s = _session(
          id: 's$i',
          workoutId: 'w$i',
          start: DateTime(2026, 1, 1).add(Duration(days: i)),
        );
        await provider.saveWorkoutCompletion(s.toWorkoutHistory(), session: s);
      }
      final keys = LocalStorage.getUserProgress().appliedWorkoutKeys;
      expect(keys, hasLength(50));
      expect(keys.last, contains('|w54|'));
    });
  });

  group('cardio completion', () {
    test('saves the session, the activity and the XP', () async {
      final provider = FitnessProvider.instance;
      final before = provider.userProgress.totalXP;
      final xp = await provider.recordCardioCompletion(_cardio(), _activity());

      expect(xp, WorkoutXpCalculator.forCardio(durationSeconds: 1800));
      expect(LocalStorage.getCardioSessions(), hasLength(1));
      expect(
        LocalStorage.getActivityRecords().any((a) => a.id == 'act_cardio_1'),
        isTrue,
      );
      expect(LocalStorage.getUserProgress().totalXP - before, xp);
      expect(provider.userProgress.totalXP - before, xp);
    });

    test(
      'cardio XP is not lost when a strength workout is saved next',
      () async {
        final provider = FitnessProvider.instance;
        final before = provider.userProgress.totalXP;
        final cardioXp = await provider.recordCardioCompletion(
          _cardio(),
          _activity(),
        );
        final s = _session();
        await provider.saveWorkoutCompletion(s.toWorkoutHistory(), session: s);
        expect(
          LocalStorage.getUserProgress().totalXP - before,
          greaterThanOrEqualTo(cardioXp + 125),
        );
      },
    );

    test('showcase mode changes only the in-memory demo state', () async {
      final provider = FitnessProvider.instance;
      final realProgress = LocalStorage.getUserProgress().toJson();
      final realActivities = LocalStorage.getActivityRecords().length;

      await LocalStorage.setShowcaseModeEnabled(true);
      await provider.onShowcaseModeToggled(true);
      final demoBefore = provider.userProgress.totalXP;

      final xp = await provider.recordCardioCompletion(_cardio(), _activity());

      // The demo athlete got the XP...
      expect(provider.userProgress.totalXP - demoBefore, xp);
      // ...and nothing real changed.
      expect(LocalStorage.getCardioSessions(), isEmpty);
      expect(LocalStorage.getActivityRecords().length, realActivities);
      expect(LocalStorage.getUserProgress().toJson(), realProgress);

      await LocalStorage.setShowcaseModeEnabled(false);
      await provider.onShowcaseModeToggled(false);
      expect(provider.userProgress.toJson(), realProgress);
    });
  });

  group('AI save_workout keeps a plan, not a completed workout', () {
    Map<String, dynamic> args({bool confirmed = true}) => {
      'action': 'save_workout',
      'workout_name': 'Chest Blaster',
      'exercises': ['Bench Press', 'Incline Dumbbell Press'],
      'duration_minutes': 45,
      'confirmed': confirmed,
    };

    test('a confirmed save is stored as a plan and nothing else', () async {
      final progressBefore = LocalStorage.getUserProgress().toJson();
      final result = await WorkoutTool().execute(args());

      expect(result['status'], 'success');
      expect(result['saved'], isTrue);
      expect(result['completed'], isFalse);
      expect(result['recorded_as'], 'planned');

      final plans = LocalStorage.getSavedWorkoutPlans();
      expect(plans, hasLength(1));
      expect(plans.single['name'], 'Chest Blaster');
      expect(plans.single['status'], 'planned');
      expect(plans.single['exercises'], [
        'Bench Press',
        'Incline Dumbbell Press',
      ]);
      // No measured figures were made up for it.
      for (final key in [
        'totalVolume',
        'totalSets',
        'totalReps',
        'caloriesBurned',
        'xpEarned',
        'completionPercentage',
      ]) {
        expect(plans.single.containsKey(key), isFalse, reason: key);
      }

      // It is not a completed workout, so statistics and progress are untouched.
      expect(LocalStorage.getWorkoutHistory(), isEmpty);
      expect(LocalStorage.getWorkoutSessions(), isEmpty);
      expect(FitnessProvider.instance.workoutHistory, isEmpty);
      expect(LocalStorage.getUserProgress().toJson(), progressBefore);
    });

    test('saving the same plan twice keeps one copy', () async {
      await WorkoutTool().execute(args());
      await WorkoutTool().execute(args());
      expect(LocalStorage.getSavedWorkoutPlans(), hasLength(1));
    });

    test('without confirmation nothing is saved', () async {
      final result = await WorkoutTool().execute(args(confirmed: false));
      expect(result['status'], 'confirmation_required');
      expect(LocalStorage.getSavedWorkoutPlans(), isEmpty);
      expect(LocalStorage.getWorkoutHistory(), isEmpty);
    });

    test('the saved plan never reaches the weekly numbers', () async {
      await WorkoutTool().execute(args());
      final history = WorkoutHistory(
        workoutName: 'Real one',
        dateCompleted: DateTime.now(),
        durationSeconds: 1800,
        exercisesCompleted: 3,
        completionPercentage: 100,
        totalVolume: 1000,
      );
      await FitnessProvider.instance.saveWorkoutCompletion(history);
      final stored = LocalStorage.getWorkoutHistory();
      expect(stored, hasLength(1));
      expect(stored.single.totalVolume, 1000);
    });
  });
}
