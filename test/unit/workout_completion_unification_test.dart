import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
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
          WorkoutSessionSet(
            setNumber: 2,
            weight: 60,
            reps: 10,
            completed: true,
          ),
        ],
        isCompleted: true,
      ),
    ],
    completedExercises: 1,
    totalVolume: 1200,
    caloriesBurned: 250,
    duration: const Duration(minutes: 45),
    personalRecords: prs,
  );
}

WorkoutHistory _entry(
  DateTime at, {
  double completion = 100,
  bool pr = false,
}) => WorkoutHistory(
  workoutName: 'Leg Day',
  dateCompleted: at,
  durationSeconds: 3000,
  exercisesCompleted: 5,
  completionPercentage: completion,
  personalRecords: pr ? const ['Squat PR'] : const [],
);

/// XP from weekly challenges completed by this workout (separate bonus).
int _challengeXp(WorkoutCompletionResult result) => result.rewards
    .where((r) => r.type == RewardType.weeklyChallenge)
    .fold(0, (sum, r) => sum + (r.data.xpReward as int));

DateTime _daysAgo(int n, {int hour = 18}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n, hour);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.instance.refreshAll();
  });

  tearDown(() async {
    await LocalStorage.setShowcaseModeEnabled(false);
    await FitnessProvider.instance.onShowcaseModeToggled(false);
  });

  group('WorkoutXpCalculator is the one XP rule', () {
    WorkoutXpBreakdown xp({
      double completion = 100,
      bool pr = false,
      int streak = 1,
    }) => WorkoutXpCalculator.forWorkout(
      completionPercentage: completion,
      hasPersonalRecord: pr,
      streakAfterWorkout: streak,
    );

    test('base, completion bonus and personal record bonus', () {
      expect(xp(completion: 50).total, 100);
      expect(xp(completion: 89.9).total, 100);
      expect(xp(completion: 90).total, 125);
      expect(xp(completion: 100, pr: true).total, 375);
    });

    test('the streak bonus lands on every seventh day only', () {
      expect(xp(streak: 6).streakBonus, 0);
      expect(xp(streak: 7).streakBonus, 250);
      expect(xp(streak: 8).streakBonus, 0);
      expect(xp(streak: 14).streakBonus, 250);
      expect(xp(streak: 0).streakBonus, 0);
      expect(xp(completion: 100, pr: true, streak: 7).total, 625);
    });

    test('cardio XP is 15 per full minute plus 50', () {
      expect(WorkoutXpCalculator.forCardio(durationSeconds: 0), 50);
      expect(WorkoutXpCalculator.forCardio(durationSeconds: 59), 50);
      expect(WorkoutXpCalculator.forCardio(durationSeconds: 1800), 500);
    });

    test('GamificationService applies exactly the calculator amount', () async {
      final service = GamificationService();
      const start = UserProgress(
        totalXP: 1000,
        completedWorkouts: 2,
        workoutStreak: 2,
        longestStreak: 2,
        totalWorkoutMinutes: 0,
        totalVolumeLifted: 0,
        rankedUnlocked: false,
        currentRank: 'Unranked',
        currentDivision: 'Unranked',
        achievements: [],
      );
      final workout = _entry(DateTime.now(), pr: true);

      // Without a streak given: the stored streak plus this workout.
      final implicit = await service.awardWorkoutXP(workout, start);
      expect(implicit.totalXP - 1000, xp(pr: true, streak: 3).total);
      // With the streak given by the caller, that streak is used.
      final explicit = await service.awardWorkoutXP(workout, start, 7);
      expect(explicit.totalXP - 1000, xp(pr: true, streak: 7).total);
      expect(explicit.workoutStreak, 7);
    });
  });

  group('one completion flow', () {
    test('the XP stored on the record is the XP awarded', () async {
      final provider = FitnessProvider.instance;
      final before = provider.userProgress.totalXP;

      final result = await provider.saveWorkoutCompletion(
        _session().toWorkoutHistory(),
        session: _session(),
      );

      final stored = LocalStorage.getWorkoutHistory().single;
      final storedSession = LocalStorage.getWorkoutSessions().single;
      // First workout, fully completed, no personal record.
      expect(stored.xpEarned, 125);
      expect(storedSession.xpEarned, 125);
      expect(provider.userProgress.totalXP - before, result.xpEarned);
      expect(result.xpEarned, 125);
      expect(result.isDuplicate, isFalse);
    });

    test(
      'a caller-supplied xpEarned is replaced by the calculated one',
      () async {
        final provider = FitnessProvider.instance;
        final session = _session().copyWith(xpEarned: 9999);
        await provider.saveWorkoutCompletion(
          session.toWorkoutHistory(),
          session: session,
        );
        expect(LocalStorage.getWorkoutHistory().single.xpEarned, 125);
      },
    );

    test('a personal record adds its bonus once', () async {
      final provider = FitnessProvider.instance;
      final session = _session(prs: const ['Bench Press: weight PR']);
      await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );
      expect(LocalStorage.getWorkoutHistory().single.xpEarned, 375);
    });

    test(
      'the seventh consecutive day gets the streak bonus, the sixth does not',
      () async {
        // Five earlier days, then today: the sixth day in a row.
        await LocalStorage.saveWorkoutHistory([
          for (var i = 1; i <= 5; i++) _entry(_daysAgo(i)),
        ]);
        FitnessProvider.instance.refreshAll();
        var provider = FitnessProvider.instance;
        var xpBefore = provider.userProgress.totalXP;
        var result = await provider.saveWorkoutCompletion(
          _entry(DateTime.now()),
        );
        expect(provider.workoutHistory.first.xpEarned, 125);
        // The workout XP actually added is the same amount (a completed
        // weekly challenge adds its own bonus on top).
        expect(
          provider.userProgress.totalXP - xpBefore - _challengeXp(result),
          125,
        );

        // Six earlier days, then today: the seventh.
        SharedPreferences.setMockInitialValues({});
        await LocalStorage.init();
        await LocalStorage.saveWorkoutHistory([
          for (var i = 1; i <= 6; i++) _entry(_daysAgo(i)),
        ]);
        provider.refreshAll();
        xpBefore = provider.userProgress.totalXP;
        result = await provider.saveWorkoutCompletion(_entry(DateTime.now()));
        expect(provider.workoutHistory.first.xpEarned, 375);
        expect(
          provider.userProgress.totalXP - xpBefore - _challengeXp(result),
          375,
        );
        expect(provider.userProgress.workoutStreak, 7);
      },
    );
  });

  group('the same workout cannot award XP twice', () {
    test('submitting it again saves and awards nothing', () async {
      final provider = FitnessProvider.instance;
      final session = _session();
      await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );
      final xpAfterFirst = provider.userProgress.totalXP;
      final completedAfterFirst = provider.userProgress.completedWorkouts;

      final again = await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );

      expect(again.isDuplicate, isTrue);
      expect(again.xpEarned, 0);
      expect(provider.userProgress.totalXP, xpAfterFirst);
      expect(provider.userProgress.completedWorkouts, completedAfterFirst);
      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(LocalStorage.getWorkoutSessions(), hasLength(1));
    });

    test(
      'a second tap that builds a new session id for the same workout',
      () async {
        final provider = FitnessProvider.instance;
        final start = DateTime.now().subtract(const Duration(minutes: 45));
        final first = _session(id: 'session_a', start: start);
        final second = _session(id: 'session_b', start: start);

        await provider.saveWorkoutCompletion(
          first.toWorkoutHistory(),
          session: first,
        );
        final xp = provider.userProgress.totalXP;
        final again = await provider.saveWorkoutCompletion(
          second.toWorkoutHistory(),
          session: second,
        );

        expect(again.isDuplicate, isTrue);
        expect(provider.userProgress.totalXP, xp);
        expect(LocalStorage.getWorkoutSessions(), hasLength(1));
      },
    );

    test('two submissions racing each other record one workout', () async {
      final provider = FitnessProvider.instance;
      final session = _session();
      final before = provider.userProgress.totalXP;

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
      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(provider.userProgress.totalXP - before, results[0].xpEarned);
    });

    test('a plain history entry is guarded the same way', () async {
      final provider = FitnessProvider.instance;
      final entry = _entry(DateTime.now());
      await provider.saveWorkoutCompletion(entry);
      final xp = provider.userProgress.totalXP;

      final again = await provider.saveWorkoutCompletion(entry);
      expect(again.isDuplicate, isTrue);
      expect(provider.userProgress.totalXP, xp);
      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
    });

    test('two different workouts both count', () async {
      final provider = FitnessProvider.instance;
      final a = _session(id: 'a', workoutId: 'w1', start: _daysAgo(0, hour: 8));
      final b = _session(
        id: 'b',
        workoutId: 'w1',
        start: _daysAgo(0, hour: 17),
      );
      await provider.saveWorkoutCompletion(a.toWorkoutHistory(), session: a);
      final second = await provider.saveWorkoutCompletion(
        b.toWorkoutHistory(),
        session: b,
      );
      expect(second.isDuplicate, isFalse);
      expect(LocalStorage.getWorkoutSessions(), hasLength(2));
    });

    test('a failed first attempt can be retried', () async {
      // Nothing was saved yet, so a retry is a first submission.
      final provider = FitnessProvider.instance;
      final session = _session();
      final result = await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );
      expect(result.isDuplicate, isFalse);
    });
  });

  group('showcase mode keeps the real data untouched', () {
    test('finishing a workout in showcase mode writes nothing real', () async {
      final provider = FitnessProvider.instance;
      final realProgressBefore = LocalStorage.getUserProgress().toJson();
      final realHistoryBefore = LocalStorage.getWorkoutHistory().length;

      await LocalStorage.setShowcaseModeEnabled(true);
      await provider.onShowcaseModeToggled(true);
      final demoBefore = provider.workoutHistory.length;

      final session = _session();
      final result = await provider.saveWorkoutCompletion(
        session.toWorkoutHistory(),
        session: session,
      );

      expect(result.xpEarned, greaterThan(0));
      expect(provider.workoutHistory.length, demoBefore + 1);
      expect(LocalStorage.getUserProgress().toJson(), realProgressBefore);
      expect(LocalStorage.getWorkoutHistory().length, realHistoryBefore);
      expect(LocalStorage.getWorkoutSessions(), isEmpty);

      // Leaving showcase mode shows the athlete's own data again.
      await LocalStorage.setShowcaseModeEnabled(false);
      await provider.onShowcaseModeToggled(false);
      expect(provider.userProgress.toJson(), realProgressBefore);
    });

    test('a repeated showcase submission does not stack demo XP', () async {
      final provider = FitnessProvider.instance;
      await LocalStorage.setShowcaseModeEnabled(true);
      await provider.onShowcaseModeToggled(true);

      final entry = _entry(DateTime.now());
      await provider.saveWorkoutCompletion(entry);
      final xp = provider.userProgress.totalXP;
      final again = await provider.saveWorkoutCompletion(entry);
      expect(again.isDuplicate, isTrue);
      expect(provider.userProgress.totalXP, xp);
    });
  });
}
