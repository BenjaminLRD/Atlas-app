import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/weekly_challenge.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/challenge_service.dart';
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

String _keyOf(WorkoutSession s) =>
    'session|${s.workoutId}|${s.startTime.millisecondsSinceEpoch}';

WorkoutHistory _entry([DateTime? at]) => WorkoutHistory(
  workoutName: 'Leg Day',
  dateCompleted: at ?? DateTime.now(),
  durationSeconds: 3000,
  exercisesCompleted: 5,
  completionPercentage: 100,
);

double _consistency() => ChallengeService.instance
    .getChallenges()
    .firstWhere((c) => c.id == 'weekly_consistency_5')
    .currentProgress;

Future<void> _finish(WorkoutSession s) => FitnessProvider.instance
    .saveWorkoutCompletion(s.toWorkoutHistory(), session: s);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    // A fresh provider and challenge state for every test.
    FitnessProvider.resetInstance();
    ChallengeService.resetInstance();
    FitnessProvider.instance.refreshAll();
  });

  tearDown(() async {
    FitnessProvider.instance.rewardStageHook = null;
    await LocalStorage.setShowcaseModeEnabled(false);
  });

  void interruptAfter(String stage) {
    FitnessProvider.instance.rewardStageHook = (s) async {
      if (s == stage) throw StateError('interrupted after $stage');
    };
  }

  group('challenge progress is counted once per workout', () {
    test(
      'stopped right after the challenge state changed, before the note',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session();
        final before = _consistency();

        interruptAfter('challengesUpdated');
        await expectLater(
          provider.saveWorkoutCompletion(
            session.toWorkoutHistory(),
            session: session,
          ),
          throwsA(isA<StateError>()),
        );
        // The challenge already counted the workout; the note has not been
        // written and the progress has not been saved.
        expect(_consistency() - before, 1);
        expect(
          LocalStorage.getPendingWorkoutRewards().values.single.containsKey(
            'challengesApplied',
          ),
          isFalse,
        );
        expect(LocalStorage.getUserProgress().completedWorkouts, 0);

        provider.rewardStageHook = null;
        await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );

        expect(_consistency() - before, 1, reason: 'counted twice');
        expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      },
    );

    test(
      'the challenge bonus is paid once when the stop was at that boundary',
      () async {
        final provider = FitnessProvider.instance;
        // Bring the consistency challenge to one workout from done.
        for (var i = 1; i <= 4; i++) {
          await ChallengeService.instance.updateProgressOnWorkout(
            _entry(),
            completionKey: 'earlier|$i',
          );
        }
        final challenge = ChallengeService.instance.getChallenges().firstWhere(
          (c) => c.id == 'weekly_consistency_5',
        );
        expect(challenge.completed, isFalse);

        final session = _session();
        final xpBefore = provider.userProgress.totalXP;
        interruptAfter('challengesUpdated');
        await expectLater(
          provider.saveWorkoutCompletion(
            session.toWorkoutHistory(),
            session: session,
          ),
          throwsA(isA<StateError>()),
        );
        // The fifth workout completed it, but nothing was paid yet.
        expect(
          ChallengeService.instance
              .getChallenges()
              .firstWhere((c) => c.id == 'weekly_consistency_5')
              .completed,
          isTrue,
        );
        expect(LocalStorage.getUserProgress().totalXP, xpBefore);

        provider.rewardStageHook = null;
        final retry = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );

        final paid = retry.rewards
            .where((r) => r.data is WeeklyChallenge)
            .map((r) => (r.data as WeeklyChallenge).xpReward)
            .fold(0, (a, b) => a + b);
        expect(paid, challenge.xpReward);
        // Workout XP (125) plus that challenge bonus, once.
        expect(
          LocalStorage.getUserProgress().totalXP - xpBefore,
          greaterThanOrEqualTo(125 + challenge.xpReward),
        );
        expect(
          LocalStorage.getUserProgress().totalXP - xpBefore,
          lessThan(125 + 2 * challenge.xpReward),
        );
      },
    );

    test(
      'the personal challenges are not counted again by the retry',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session();
        Future<double> userTotal() async =>
            (await ChallengeService.instance.getUserChallenges()).fold<double>(
              0.0,
              (sum, u) => sum + u.progress,
            );

        final start = await userTotal();
        interruptAfter('challengesUpdated');
        await expectLater(_finish(session), throwsA(isA<StateError>()));
        final afterStop = await userTotal();
        expect(
          afterStop,
          greaterThan(start),
          reason: 'counted before the stop',
        );

        provider.rewardStageHook = null;
        await _finish(session);
        expect(
          await userTotal(),
          afterStop,
          reason: 'the retry counted it again',
        );
      },
    );

    test('the same workout key changes a challenge only once', () async {
      final service = ChallengeService.instance;
      final first = _consistency();
      await service.updateProgressOnWorkout(_entry(), completionKey: 'k');
      await service.updateProgressOnWorkout(_entry(), completionKey: 'k');
      expect(_consistency() - first, 1);
      await service.updateProgressOnWorkout(_entry(), completionKey: 'other');
      expect(_consistency() - first, 2);
    });

    test('the personal challenge list counts a workout once as well', () async {
      final service = ChallengeService.instance;
      Future<double> total() async => (await service.getUserChallenges())
          .fold<double>(0.0, (sum, u) => sum + u.progress);
      final before = await total();

      await service.updateWorkoutProgress(
        userId: 'usr_local',
        workout: _entry(),
        completionKey: 'k1',
      );
      final once = await total();
      expect(once, greaterThan(before));
      await service.updateWorkoutProgress(
        userId: 'usr_local',
        workout: _entry(),
        completionKey: 'k1',
      );
      expect(await total(), once);
      await service.updateWorkoutProgress(
        userId: 'usr_local',
        workout: _entry(),
        completionKey: 'k2',
      );
      expect(await total(), greaterThan(once));
    });

    test('a stored challenge without the new fields still loads', () {
      final c = WeeklyChallenge.fromJson({
        'id': 'a',
        'title': 't',
        'description': 'd',
        'category': 'training',
        'targetValue': 5,
        'currentProgress': 2,
        'xpReward': 500,
        'completed': false,
      });
      expect(c.appliedWorkoutKeys, isEmpty);
      expect(c.completedByKey, isNull);
      expect(c.toJson().containsKey('appliedWorkoutKeys'), isFalse);
    });
  });

  group(
    'the applied-key limit does not let an old workout be rewarded again',
    () {
      Future<void> completeMany(int count, {int offset = 0}) async {
        for (var i = 0; i < count; i++) {
          final s = _session(
            id: 'many_${offset + i}',
            workoutId: 'many_${offset + i}',
            start: DateTime(2026, 1, 1).add(Duration(days: offset + i)),
          );
          await _finish(s);
        }
      }

      test('resubmitting a long-finished workout is a duplicate', () async {
        final provider = FitnessProvider.instance;
        final old = _session(id: 'old', workoutId: 'old');
        await _finish(old);
        await completeMany(60);
        expect(
          LocalStorage.getUserProgress().appliedWorkoutKeys,
          isNot(contains(_keyOf(old))),
          reason: 'its key has been evicted',
        );

        final xp = LocalStorage.getUserProgress().totalXP;
        final workouts = LocalStorage.getUserProgress().completedWorkouts;
        final again = await provider.saveWorkoutCompletion(
          old.toWorkoutHistory(),
          session: old,
        );

        // Saved sessions and history are permanent, so the key is not needed.
        expect(again.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xp);
        expect(LocalStorage.getUserProgress().completedWorkouts, workouts);
        expect(
          LocalStorage.getWorkoutSessions().where((s) => s.workoutId == 'old'),
          hasLength(1),
        );
      });

      test('a workout whose note is still open keeps its key', () async {
        final provider = FitnessProvider.instance;
        final old = _session(id: 'old', workoutId: 'old');
        await _finish(old);
        // The app stopped after saving the progress, before clearing the note.
        await LocalStorage.savePendingWorkoutReward(_keyOf(old), {
          'entry': LocalStorage.getWorkoutHistory().single.toJson(),
        });

        await completeMany(60);
        expect(
          LocalStorage.getUserProgress().appliedWorkoutKeys,
          contains(_keyOf(old)),
          reason: 'an open note protects its key from eviction',
        );
        expect(
          LocalStorage.getUserProgress().appliedWorkoutKeys.length,
          lessThanOrEqualTo(51),
        );

        final xp = LocalStorage.getUserProgress().totalXP;
        final again = await provider.saveWorkoutCompletion(
          old.toWorkoutHistory(),
          session: old,
        );
        expect(again.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xp);
        expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
      });

      test(
        'an interrupted workout is still finished after many others',
        () async {
          final provider = FitnessProvider.instance;
          final stuck = _session(id: 'stuck', workoutId: 'stuck');
          interruptAfter('recordSaved');
          await expectLater(_finish(stuck), throwsA(isA<StateError>()));
          provider.rewardStageHook = null;

          await completeMany(60);
          final before = LocalStorage.getUserProgress().completedWorkouts;
          final result = await provider.saveWorkoutCompletion(
            stuck.toWorkoutHistory(),
            session: stuck,
          );

          expect(result.isDuplicate, isFalse);
          expect(LocalStorage.getUserProgress().completedWorkouts, before + 1);
          expect(
            LocalStorage.getUserProgress().appliedWorkoutKeys,
            contains(_keyOf(stuck)),
          );
        },
      );

      test(
        'progress saved before this change loads and keeps working',
        () async {
          final json = UserProgress.initial().toJson()
            ..remove('appliedWorkoutKeys')
            ..['totalXP'] = 700;
          await LocalStorage.saveUserProgress(UserProgress.fromJson(json));
          FitnessProvider.instance.refreshAll();
          await _finish(_session());
          expect(
            LocalStorage.getUserProgress().totalXP,
            greaterThanOrEqualTo(825),
          );
          expect(
            LocalStorage.getUserProgress().appliedWorkoutKeys,
            hasLength(1),
          );
        },
      );
    },
  );

  group('the AI memory note is recovered and not duplicated', () {
    int events(String idPrefix) => FitnessMemory.instance
        .getEvents()
        .where((e) => e.id.startsWith(idPrefix))
        .length;

    test(
      'stopped after the rewards were saved, before the memory note',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session(prs: const ['Bench PR']);
        final key = _keyOf(session);

        interruptAfter('rewardsApplied');
        await expectLater(_finish(session), throwsA(isA<StateError>()));
        expect(events('evt_wo_$key'), 0);
        expect(
          LocalStorage.getPendingWorkoutRewards()[key]!['progressApplied'],
          isTrue,
        );
        final xp = LocalStorage.getUserProgress().totalXP;

        provider.rewardStageHook = null;
        final retry = await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );

        expect(retry.isDuplicate, isTrue);
        expect(LocalStorage.getUserProgress().totalXP, xp, reason: 'no new XP');
        expect(events('evt_wo_$key'), 1);
        expect(events('evt_pr_$key'), 1);
        expect(events('evt_perf_$key'), 1);
        expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
      },
    );

    test('recording the same workout twice keeps one note', () async {
      final session = _session(prs: const ['Bench PR']);
      final key = _keyOf(session);
      await FitnessMemory.instance.recordWorkoutExecution(
        workoutTitle: 'Push Day',
        totalVolume: 600,
        completedSets: 1,
        prs: session.personalRecords,
        exercises: session.exercises,
        completionKey: key,
      );
      await FitnessMemory.instance.recordWorkoutExecution(
        workoutTitle: 'Push Day',
        totalVolume: 600,
        completedSets: 1,
        prs: session.personalRecords,
        exercises: session.exercises,
        completionKey: key,
      );
      expect(events('evt_wo_$key'), 1);
      expect(events('evt_pr_$key'), 1);
      expect(events('evt_perf_$key'), 1);
    });

    test('an uninterrupted completion writes the note once', () async {
      final session = _session();
      await _finish(session);
      expect(events('evt_wo_${_keyOf(session)}'), 1);
    });
  });

  group('cardio retry', () {
    CardioSession cardio() => CardioSession(
      id: 'cardio_fixed',
      exerciseId: 'run',
      exerciseName: 'Run',
      category: 'Running',
      durationSeconds: 1200,
      distanceKm: 3,
      caloriesBurned: 200,
      startTime: DateTime.now().subtract(const Duration(minutes: 20)),
      endTime: DateTime.now(),
      metValue: 9,
      isCompleted: true,
    );
    ActivityRecord activity() => ActivityRecord(
      id: 'act_cardio_fixed',
      date: DateTime.now(),
      steps: 4000,
      activeMinutes: 20,
      caloriesBurned: 200,
      distanceKm: 3,
      type: ActivityType.cardio,
      title: 'Run',
    );

    test('stopped after saving the session, then finished again', () async {
      final provider = FitnessProvider.instance;
      final before = LocalStorage.getUserProgress().totalXP;

      interruptAfter('cardioSaved');
      await expectLater(
        provider.recordCardioCompletion(cardio(), activity()),
        throwsA(isA<StateError>()),
      );
      expect(LocalStorage.getCardioSessions(), hasLength(1));
      expect(LocalStorage.getUserProgress().totalXP, before);

      provider.rewardStageHook = null;
      final xp = await provider.recordCardioCompletion(cardio(), activity());
      expect(xp, 350);
      // A third press changes nothing.
      expect(await provider.recordCardioCompletion(cardio(), activity()), 0);

      expect(LocalStorage.getCardioSessions(), hasLength(1));
      expect(
        LocalStorage.getActivityRecords().where(
          (a) => a.id == 'act_cardio_fixed',
        ),
        hasLength(1),
      );
      expect(LocalStorage.getUserProgress().totalXP - before, 350);
    });
  });

  group('saved AI plans', () {
    Map<String, dynamic> args({int minutes = 45}) => {
      'action': 'save_workout',
      'workout_name': 'Chest Blaster',
      'exercises': ['Bench Press', 'Incline Dumbbell Press'],
      'duration_minutes': minutes,
      'confirmed': true,
    };

    test('keeps the plan exactly as proposed', () async {
      await WorkoutTool().execute(args());
      final plan = LocalStorage.getSavedWorkoutPlans().single;
      expect(plan['name'], 'Chest Blaster');
      expect(plan['exercises'], ['Bench Press', 'Incline Dumbbell Press']);
      expect(plan['durationMinutes'], 45);
      expect(plan['status'], 'planned');
      expect(plan['source'], 'ai_coach');
      expect(DateTime.tryParse(plan['savedAt'] as String), isNotNull);
    });

    test('saving it again keeps one copy and the newest details', () async {
      await WorkoutTool().execute(args());
      await WorkoutTool().execute(args(minutes: 60));
      final plans = LocalStorage.getSavedWorkoutPlans();
      expect(plans, hasLength(1));
      expect(plans.single['durationMinutes'], 60);
    });

    test('a different set of exercises is a different plan', () async {
      await WorkoutTool().execute(args());
      await WorkoutTool().execute({
        ...args(),
        'exercises': ['Squat'],
      });
      expect(LocalStorage.getSavedWorkoutPlans(), hasLength(2));
    });

    test('plans never touch history, sessions, progress or XP', () async {
      final progress = LocalStorage.getUserProgress().toJson();
      await WorkoutTool().execute(args());
      await WorkoutTool().execute(args(minutes: 30));
      expect(LocalStorage.getWorkoutHistory(), isEmpty);
      expect(LocalStorage.getWorkoutSessions(), isEmpty);
      expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
      expect(LocalStorage.getUserProgress().toJson(), progress);
    });
  });
}
