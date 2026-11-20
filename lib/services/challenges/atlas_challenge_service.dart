import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_storage.dart';
import '../../models/atlas_challenge.dart';
import '../../models/reward_event.dart';
import '../community/sample_world.dart';
import '../gamification/bonus_xp.dart';
import '../reward_queue_service.dart';
import 'challenge_progress.dart';

/// Your challenges: self-challenges and challenges against sample athletes.
///
/// * Your progress is counted from your recorded workouts and step readings.
/// * A sample opponent's progress is scripted and always labelled.
/// * Nothing is shared with other people: there is no server feature for
///   challenges between real members yet.
/// * Self-challenges and sample-opponent challenges are stored under separate
///   keys so sample content never mixes into your own records.
class AtlasChallengeService {
  static const _selfKey = 'atlas_challenges_self_v1';
  static const _sampleKey = 'atlas_challenges_sample_v1';
  static const _seededKey = 'atlas_challenges_seeded_v1';

  static AtlasChallengeService? _instance;
  static AtlasChallengeService get instance =>
      _instance ??= AtlasChallengeService();
  static void resetInstance() => _instance = null;

  final XpAwarder? _awardXp;
  AtlasChallengeService({this._awardXp});

  Future<void> _award(int amount) => (_awardXp ?? BonusXp.awarder)(amount);

  final Set<String> _paying = {};

  // ---------------------------------------------------------- storage
  List<AtlasChallenge> _read(String key) {
    final raw = LocalStorage.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          AtlasChallenge.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<AtlasChallenge> all) async {
    await LocalStorage.setString(
      _selfKey,
      jsonEncode([for (final c in all.where((c) => !c.isSample)) c.toJson()]),
    );
    await LocalStorage.setString(
      _sampleKey,
      jsonEncode([for (final c in all.where((c) => c.isSample)) c.toJson()]),
    );
  }

  /// Every challenge, newest first.
  List<AtlasChallenge> all() {
    final list = [..._read(_selfKey), ..._read(_sampleKey)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  AtlasChallenge? byId(String id) {
    for (final c in all()) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<AtlasChallenge> invitations() => [
    for (final c in all())
      if (c.status == AtlasChallengeStatus.invited) c,
  ];
  List<AtlasChallenge> active() => [
    for (final c in all())
      if (c.status == AtlasChallengeStatus.active) c,
  ];
  List<AtlasChallenge> past() => [
    for (final c in all())
      if (!c.isOpen) c,
  ];

  // ----------------------------------------------------------- create
  static int _seq = 0;
  static String _newId() =>
      'ch_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  AtlasChallenge _started(AtlasChallenge c, DateTime now) {
    final start = ChallengeProgressCalculator.dayStart(now);
    return c.copyWith(
      status: AtlasChallengeStatus.active,
      startDate: start,
      endDate: DateTime(start.year, start.month, start.day + c.durationDays),
    );
  }

  /// Starts a challenge you set yourself, or one against a sample athlete
  /// ([opponentKey]). Sample athletes always accept (a scripted demo), so it
  /// starts immediately; it is labelled as sample throughout.
  Future<AtlasChallenge> create({
    required String title,
    required ChallengeMetric metric,
    required double target,
    required int durationDays,
    int stepGoal = 10000,
    int xpReward = 0,
    String? opponentKey,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final c = _started(
      AtlasChallenge(
        id: _newId(),
        title: title,
        metric: metric,
        target: target,
        durationDays: durationDays.clamp(1, 90),
        createdAt: clock,
        status: AtlasChallengeStatus.active,
        stepGoal: stepGoal,
        opponentKey: opponentKey,
        xpReward: xpReward,
      ),
      clock,
    );
    await _write([c, ...all()]);
    return c;
  }

  Future<AtlasChallenge> createFromPreset(
    ChallengePreset p, {
    String? opponentKey,
    DateTime? now,
  }) => create(
    title: p.title,
    metric: p.metric,
    target: p.target,
    durationDays: p.durationDays,
    stepGoal: p.stepGoal,
    xpReward: p.xpReward,
    opponentKey: opponentKey,
    now: now,
  );

  /// Adds two sample invitations the first time, so the invited, accepted and
  /// declined states can be tried. They are sample content and labelled so.
  Future<void> seedSampleInvitationsOnce({DateTime? now}) async {
    if (LocalStorage.getString(_seededKey) == '1') return;
    final clock = now ?? DateTime.now();
    AtlasChallenge invite(
      String key,
      String title,
      ChallengeMetric m,
      double target,
      int days,
    ) => AtlasChallenge(
      id: 'ch_invite_$key',
      title: title,
      metric: m,
      target: target,
      durationDays: days,
      createdAt: clock,
      status: AtlasChallengeStatus.invited,
      opponentKey: key,
      incoming: true,
      inviteExpiresAt: clock.add(const Duration(days: 3)),
    );
    final invites = [
      if (SampleWorld.byKey('zothanpuii') != null)
        invite(
          'zothanpuii',
          '5 days at 10,000 steps',
          ChallengeMetric.stepDays,
          5,
          7,
        ),
      if (SampleWorld.byKey('marcus') != null)
        invite(
          'marcus',
          '4 workouts in a week',
          ChallengeMetric.workouts,
          4,
          7,
        ),
    ];
    await _write([...invites, ...all()]);
    await LocalStorage.setString(_seededKey, '1');
  }

  // ---------------------------------------------------------- actions
  Future<void> accept(String id, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final list = all();
    final i = list.indexWhere((c) => c.id == id);
    if (i == -1 || list[i].status != AtlasChallengeStatus.invited) return;
    list[i] = _started(list[i], clock);
    await _write(list);
  }

  Future<void> decline(String id) async {
    final list = all();
    final i = list.indexWhere((c) => c.id == id);
    if (i == -1 || list[i].status != AtlasChallengeStatus.invited) return;
    list[i] = list[i].copyWith(status: AtlasChallengeStatus.declined);
    await _write(list);
  }

  Future<void> remove(String id) async {
    await _write([
      for (final c in all())
        if (c.id != id) c,
    ]);
  }

  // ---------------------------------------------------------- refresh
  /// Re-checks every open challenge against your recorded data, moves it to
  /// completed or expired when that is true, and pays the XP for a completed
  /// one once. Returns true when something changed.
  Future<bool> refresh(ChallengeInputs inputs) async {
    final list = all();
    var changed = false;
    final toPay = <AtlasChallenge>[];
    for (var i = 0; i < list.length; i++) {
      final updated = evaluate(list[i], inputs);
      if (updated != null) {
        list[i] = updated;
        changed = true;
        if (updated.status == AtlasChallengeStatus.completed &&
            updated.xpReward > 0 &&
            !updated.rewardPaid) {
          toPay.add(updated);
        }
      }
    }
    // Completed challenges whose XP was never paid (for example the award
    // failed last time) are retried.
    for (final c in list) {
      if (c.status == AtlasChallengeStatus.completed &&
          c.xpReward > 0 &&
          !c.rewardPaid &&
          !toPay.any((t) => t.id == c.id)) {
        toPay.add(c);
      }
    }
    if (changed) await _write(list);
    for (final c in toPay) {
      await _pay(c);
    }
    return changed;
  }

  /// The new state of [c] if it should change, else null. Pure.
  AtlasChallenge? evaluate(AtlasChallenge c, ChallengeInputs inputs) {
    final now = inputs.now;
    if (c.status == AtlasChallengeStatus.invited) {
      final exp = c.inviteExpiresAt;
      if (exp != null && !now.isBefore(exp)) {
        return c.copyWith(
          status: AtlasChallengeStatus.expired,
          endNote: 'The invitation was not answered in time.',
        );
      }
      return null;
    }
    if (c.status != AtlasChallengeStatus.active) return null;

    final you = ChallengeProgressCalculator.forYou(c, inputs);
    if (you.available && you.value! >= c.target) {
      return c.copyWith(
        status: AtlasChallengeStatus.completed,
        completedAt: now,
      );
    }
    final sample = c.opponentKey == null
        ? null
        : SampleWorld.byKey(c.opponentKey!);
    if (sample != null) {
      final opp = ChallengeProgressCalculator.scriptedOpponent(c, sample, now);
      if (opp >= c.target) {
        return c.copyWith(
          status: AtlasChallengeStatus.expired,
          endNote:
              '${sample.name} (sample) reached the goal first. Their progress '
              'is scripted.',
        );
      }
    }
    final end = c.endDate;
    if (end != null && !now.isBefore(end)) {
      return c.copyWith(
        status: AtlasChallengeStatus.expired,
        endNote: 'Time ran out before the goal was reached.',
      );
    }
    return null;
  }

  Future<void> _pay(AtlasChallenge c) async {
    if (!_paying.add(c.id)) return;
    try {
      await _award(c.xpReward);
      final list = all();
      final i = list.indexWhere((x) => x.id == c.id);
      if (i != -1) {
        list[i] = list[i].copyWith(rewardPaid: true);
        await _write(list);
      }
      RewardQueueService.instance.enqueue(
        RewardEvent.friendChallenge(
          challengeId: c.id,
          title: 'CHALLENGE COMPLETE!',
          xpGained: c.xpReward,
          data: {'amount': c.xpReward, 'source': c.title},
        ),
      );
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'challenges',
          context: ErrorDescription('while awarding XP for "${c.title}"'),
        ),
      );
    } finally {
      _paying.remove(c.id);
    }
  }
}
