import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/atlas_challenge.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/services/challenges/challenge_progress.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/services/reward_queue_service.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-11-16 is a Monday.
final _mon = DateTime(2026, 11, 16);

WorkoutHistory _w(DateTime at, {int seconds = 3600, double volume = 1000}) =>
    WorkoutHistory(
      workoutName: 'Session',
      dateCompleted: at,
      durationSeconds: seconds,
      exercisesCompleted: 3,
      completionPercentage: 100,
      totalVolume: volume,
      totalSets: 9,
      totalReps: 90,
    );

DayStepTotal _steps(DateTime day, int? n) =>
    DayStepTotal(dayKey: stepDayKey(day), steps: n);

ChallengeInputs _in(
  DateTime now, {
  List<WorkoutHistory> history = const [],
  List<DayStepTotal> steps = const [],
}) => ChallengeInputs(history: history, stepDays: steps, now: now);

AtlasChallenge _ch(
  ChallengeMetric m,
  double target, {
  int days = 7,
  int stepGoal = 10000,
  String? opponent,
  AtlasChallengeStatus status = AtlasChallengeStatus.active,
  int xp = 0,
}) => AtlasChallenge(
  id: 'c1',
  title: 't',
  metric: m,
  target: target,
  durationDays: days,
  createdAt: _mon,
  status: status,
  stepGoal: stepGoal,
  startDate: _mon,
  endDate: DateTime(2026, 11, 16 + days),
  opponentKey: opponent,
  xpReward: xp,
);

class _Awards {
  final amounts = <int>[];
  bool failing = false;
  Future<void> call(int a) async {
    if (failing) throw StateError('award failed');
    amounts.add(a);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AtlasChallengeService.resetInstance();
    RewardQueueService.resetInstance();
  });

  group('your progress is counted from real records', () {
    final now = DateTime(2026, 11, 20, 12);

    test('workouts count only inside the window and not in the future', () {
      final c = _ch(ChallengeMetric.workouts, 4);
      final p = ChallengeProgressCalculator.forYou(
        c,
        _in(
          now,
          history: [
            _w(DateTime(2026, 11, 15, 23, 59, 59)), // before the start
            _w(DateTime(2026, 11, 16, 0, 0, 0)), // first moment
            _w(DateTime(2026, 11, 19, 9)),
            _w(DateTime(2026, 11, 22, 8)), // later than now
            _w(DateTime(2026, 11, 23, 0, 0, 0)), // after the end
          ],
        ),
      );
      expect(p.value, 2);
    });

    test('minutes and volume come from the logged sessions', () {
      final h = [
        _w(DateTime(2026, 11, 17, 8), seconds: 2700, volume: 4000),
        _w(DateTime(2026, 11, 18, 8), seconds: 3030, volume: 6500.5),
        _w(DateTime(2026, 11, 1, 8), seconds: 9999, volume: 99999),
      ];
      expect(
        ChallengeProgressCalculator.forYou(
          _ch(ChallengeMetric.minutes, 100),
          _in(now, history: h),
        ).value,
        95, // 45 + 50 (50.5 floors)... 2700s + 3030s = 5730s = 95.5 -> 95
      );
      expect(
        ChallengeProgressCalculator.forYou(
          _ch(ChallengeMetric.volumeKg, 20000),
          _in(now, history: h),
        ).value,
        10500.5,
      );
    });

    test('no logged workout is a recorded zero, not unavailable', () {
      final p = ChallengeProgressCalculator.forYou(
        _ch(ChallengeMetric.workouts, 4),
        _in(now),
      );
      expect(p.available, isTrue);
      expect(p.value, 0);
    });

    test('step days count days that reached the goal', () {
      final c = _ch(ChallengeMetric.stepDays, 7);
      final p = ChallengeProgressCalculator.forYou(
        c,
        _in(
          now,
          steps: [
            _steps(DateTime(2026, 11, 16), 10500),
            _steps(DateTime(2026, 11, 17), 9999),
            _steps(DateTime(2026, 11, 18), 10000),
            _steps(DateTime(2026, 11, 19), null),
            _steps(DateTime(2026, 11, 15), 20000), // before the window
            _steps(DateTime(2026, 11, 22), 20000), // after today
          ],
        ),
      );
      expect(p.value, 2);
    });

    test('without step readings the progress is unavailable, never zero', () {
      final c = _ch(ChallengeMetric.stepDays, 7);
      final p = ChallengeProgressCalculator.forYou(
        c,
        _in(
          now,
          steps: [
            for (var i = 0; i < 7; i++)
              _steps(DateTime(2026, 11, 16 + i), null),
          ],
        ),
      );
      expect(p.available, isFalse);
      expect(p.value, isNull);
      expect(p.note, contains('step readings'));
      expect(_in(now).stepsAvailable, isFalse);
      expect(
        _in(now, steps: [_steps(DateTime(2026, 11, 16), 5)]).stepsAvailable,
        isTrue,
      );
    });
  });

  group('scripted sample opponent', () {
    final alex = SampleWorld.byKey('alex')!;

    test('is zero before the start and capped at the target', () {
      final c = _ch(ChallengeMetric.workouts, 4, opponent: 'alex');
      expect(
        ChallengeProgressCalculator.scriptedOpponent(
          c,
          alex,
          _mon.subtract(const Duration(days: 1)),
        ),
        0,
      );
      expect(
        ChallengeProgressCalculator.scriptedOpponent(
          c,
          alex,
          DateTime(2026, 12, 30),
        ),
        4,
      );
    });

    test('follows the athlete sample pace and is deterministic', () {
      final c = _ch(ChallengeMetric.workouts, 100, opponent: 'alex');
      final at = DateTime(2026, 11, 19); // 3 days in
      final v = ChallengeProgressCalculator.scriptedOpponent(c, alex, at);
      expect(v, (alex.stats.weeklyWorkouts / 7 * 3).floor());
      expect(ChallengeProgressCalculator.scriptedOpponent(c, alex, at), v);
    });
  });

  group('status changes', () {
    final service = AtlasChallengeService();

    test('reaching the goal completes it', () {
      final c = _ch(ChallengeMetric.workouts, 2);
      final done = service.evaluate(
        c,
        _in(
          DateTime(2026, 11, 19, 12),
          history: [
            _w(DateTime(2026, 11, 17, 8)),
            _w(DateTime(2026, 11, 18, 8)),
          ],
        ),
      );
      expect(done!.status, AtlasChallengeStatus.completed);
      expect(done.completedAt, isNotNull);
    });

    test('running out of time expires it', () {
      final c = _ch(ChallengeMetric.workouts, 4);
      final e = service.evaluate(c, _in(DateTime(2026, 11, 23, 0, 0, 1)));
      expect(e!.status, AtlasChallengeStatus.expired);
      expect(e.endNote, contains('Time ran out'));
    });

    test('an open challenge with progress left stays active', () {
      expect(
        service.evaluate(
          _ch(ChallengeMetric.workouts, 4),
          _in(DateTime(2026, 11, 18)),
        ),
        isNull,
      );
    });

    test('an unanswered invitation expires', () {
      final c = AtlasChallenge(
        id: 'i',
        title: 'i',
        metric: ChallengeMetric.workouts,
        target: 3,
        durationDays: 7,
        createdAt: _mon,
        status: AtlasChallengeStatus.invited,
        opponentKey: 'marcus',
        incoming: true,
        inviteExpiresAt: _mon.add(const Duration(days: 3)),
      );
      expect(
        service.evaluate(c, _in(_mon.add(const Duration(days: 1)))),
        isNull,
      );
      expect(
        service.evaluate(c, _in(_mon.add(const Duration(days: 3))))!.status,
        AtlasChallengeStatus.expired,
      );
    });

    test('a sample opponent reaching the goal first ends it, labelled', () {
      final c = _ch(ChallengeMetric.workouts, 1, opponent: 'daniel');
      final e = service.evaluate(c, _in(DateTime(2026, 11, 20)));
      expect(e!.status, AtlasChallengeStatus.expired);
      expect(e.endNote, contains('(sample)'));
      expect(e.endNote, contains('scripted'));
    });

    test('step challenges are never completed without step readings', () {
      final c = _ch(ChallengeMetric.stepDays, 1);
      final r = service.evaluate(c, _in(DateTime(2026, 11, 18)));
      expect(r, isNull); // not completed, not expired, still waiting
    });
  });

  group('the service', () {
    test('self and sample challenges are stored under separate keys', () async {
      final s = AtlasChallengeService();
      await s.create(
        title: 'mine',
        metric: ChallengeMetric.workouts,
        target: 3,
        durationDays: 7,
        now: _mon,
      );
      await s.create(
        title: 'duel',
        metric: ChallengeMetric.minutes,
        target: 100,
        durationDays: 7,
        opponentKey: 'maya',
        now: _mon,
      );
      final self = LocalStorage.getString('atlas_challenges_self_v1')!;
      final sample = LocalStorage.getString('atlas_challenges_sample_v1')!;
      expect(self, contains('"mine"'));
      expect(self, isNot(contains('"duel"')));
      expect(sample, contains('"duel"'));
      expect(sample, isNot(contains('"mine"')));
      expect(AtlasChallengeService().all().length, 2); // survives a reload
    });

    test('a new challenge starts today and ends after its duration', () async {
      final c = await AtlasChallengeService().create(
        title: 'x',
        metric: ChallengeMetric.workouts,
        target: 3,
        durationDays: 14,
        now: DateTime(2026, 11, 18, 15, 30),
      );
      expect(c.status, AtlasChallengeStatus.active);
      expect(c.startDate, DateTime(2026, 11, 18));
      expect(c.endDate, DateTime(2026, 12, 2));
    });

    test(
      'sample invitations are seeded once, labelled, and answerable',
      () async {
        final s = AtlasChallengeService();
        await s.seedSampleInvitationsOnce(now: _mon);
        await s.seedSampleInvitationsOnce(now: _mon);
        final invites = s.invitations();
        expect(invites.length, 2);
        expect(invites.every((c) => c.isSample && c.incoming), isTrue);
        expect(invites.every((c) => c.startDate == null), isTrue);

        await s.accept(invites.first.id, now: DateTime(2026, 11, 17, 9));
        final accepted = s.byId(invites.first.id)!;
        expect(accepted.status, AtlasChallengeStatus.active);
        expect(accepted.startDate, DateTime(2026, 11, 17));

        await s.decline(invites.last.id);
        expect(s.byId(invites.last.id)!.status, AtlasChallengeStatus.declined);
        expect(s.past().map((c) => c.id), contains(invites.last.id));
        expect(s.active().map((c) => c.id), contains(invites.first.id));

        // Declining stays declined, and nothing is re-seeded.
        await AtlasChallengeService().seedSampleInvitationsOnce(now: _mon);
        expect(AtlasChallengeService().invitations(), isEmpty);
      },
    );

    test('remove deletes only that challenge', () async {
      final s = AtlasChallengeService();
      final a = await s.create(
        title: 'a',
        metric: ChallengeMetric.workouts,
        target: 1,
        durationDays: 7,
        now: _mon,
      );
      final b = await s.create(
        title: 'b',
        metric: ChallengeMetric.workouts,
        target: 1,
        durationDays: 7,
        now: _mon,
      );
      await s.remove(a.id);
      expect(s.all().map((c) => c.id), [b.id]);
    });

    test('completing a challenge pays its XP exactly once', () async {
      final awards = _Awards();
      final s = AtlasChallengeService(awardXp: awards.call);
      await s.create(
        title: 'two',
        metric: ChallengeMetric.workouts,
        target: 2,
        durationDays: 7,
        xpReward: 150,
        now: _mon,
      );
      final inputs = _in(
        DateTime(2026, 11, 18, 12),
        history: [_w(DateTime(2026, 11, 16, 8)), _w(DateTime(2026, 11, 17, 8))],
      );

      expect(await s.refresh(inputs), isTrue);
      await s.refresh(inputs);
      await s.refresh(inputs);

      expect(awards.amounts, [150]);
      final done = s.all().single;
      expect(done.status, AtlasChallengeStatus.completed);
      expect(done.rewardPaid, isTrue);
      expect(
        RewardQueueService.instance.peek()?.type,
        RewardType.friendChallenge,
      );
    });

    test('a failed award is reported and paid on the next refresh', () async {
      final awards = _Awards()..failing = true;
      final s = AtlasChallengeService(awardXp: awards.call);
      await s.create(
        title: 'one',
        metric: ChallengeMetric.workouts,
        target: 1,
        durationDays: 7,
        xpReward: 100,
        now: _mon,
      );
      final inputs = _in(
        DateTime(2026, 11, 17, 12),
        history: [_w(DateTime(2026, 11, 16, 8))],
      );

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await s.refresh(inputs);
      } finally {
        FlutterError.onError = previous;
      }
      expect(errors, hasLength(1));
      expect(errors.single.library, 'challenges');
      expect(s.all().single.rewardPaid, isFalse);
      expect(RewardQueueService.instance.hasPendingRewards, isFalse);

      awards.failing = false;
      await s.refresh(inputs);
      expect(awards.amounts, [100]);
      expect(s.all().single.rewardPaid, isTrue);
      await s.refresh(inputs);
      expect(awards.amounts, [100]);
    });

    test('a challenge with no XP reward pays nothing', () async {
      final awards = _Awards();
      final s = AtlasChallengeService(awardXp: awards.call);
      await s.create(
        title: 'free',
        metric: ChallengeMetric.workouts,
        target: 1,
        durationDays: 7,
        now: _mon,
      );
      await s.refresh(
        _in(DateTime(2026, 11, 17), history: [_w(DateTime(2026, 11, 16, 8))]),
      );
      expect(awards.amounts, isEmpty);
      expect(s.all().single.status, AtlasChallengeStatus.completed);
    });

    test('presets are all measurable metrics', () {
      for (final p in ChallengePreset.presets) {
        expect(p.target, greaterThan(0));
        expect(p.durationDays, inInclusiveRange(1, 90));
      }
      expect(ChallengePreset.presets.any((p) => p.metric.needsSteps), isTrue);
    });
  });
}
