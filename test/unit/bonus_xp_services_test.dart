import 'dart:async';
import 'dart:io';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/reward_event.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/services/gamification/bonus_xp.dart';
import 'package:atlas/services/referral_service.dart';
import 'package:atlas/services/reward_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the XP it is asked to award; can be told to fail.
class _Awards {
  final List<int> amounts = [];
  bool failing = false;
  Completer<void>? hold;

  Future<void> call(int amount) async {
    if (hold != null) await hold!.future;
    if (failing) throw StateError('award failed');
    amounts.add(amount);
  }
}

List<RewardType> _queuedTypes() {
  final types = <RewardType>[];
  final queue = RewardQueueService.instance;
  // Read the queue without consuming anything the other tests need.
  var next = queue.peek();
  if (next != null) types.add(next.type);
  return types;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
    RewardQueueService.resetInstance();
    ReferralService.resetInstance();
    AtlasChallengeService.resetInstance();
    BonusXp.awarder = BonusXp.saveOnly;
  });

  tearDown(() {
    FitnessProvider.resetInstance();
    BonusXp.awarder = BonusXp.saveOnly;
  });

  group('sources no longer refer to the provider', () {
    test('referral and challenge services', () {
      for (final path in [
        'lib/services/referral_service.dart',
        'lib/services/challenges/atlas_challenge_service.dart',
        'lib/services/gamification/bonus_xp.dart',
      ]) {
        final source = File(path).readAsStringSync();
        // No import of the provider and no use of its singleton (a mention in
        // a comment is fine).
        expect(source.contains('fitness_provider'), isFalse, reason: path);
        expect(source.contains('FitnessProvider.'), isFalse, reason: path);
      }
    });
  });

  group('ReferralService', () {
    test('claiming a code awards 250 XP once, with no provider', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      expect(await service.claimReferralCode(' atlas-friend1 '), isTrue);

      expect(awards.amounts, [250]);
      expect(RewardQueueService.instance.hasPendingRewards, isTrue);
      expect(_queuedTypes(), [RewardType.referralReward]);
    });

    test('an invalid code, or your own, awards nothing', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      expect(await service.claimReferralCode('nope'), isFalse);
      expect(await service.claimReferralCode('ATLAS-1'), isFalse); // too short
      final own = service.getReferralData().referralCode;
      expect(await service.claimReferralCode(own), isFalse);

      expect(awards.amounts, isEmpty);
      expect(RewardQueueService.instance.hasPendingRewards, isFalse);
    });

    test(
      'a failed award throws, shows no reward, and can be retried once',
      () async {
        final awards = _Awards()..failing = true;
        final service = ReferralService(awardXp: awards.call);

        await expectLater(
          service.claimReferralCode('ATLAS-FRIEND1'),
          throwsA(isA<StateError>()),
        );
        expect(RewardQueueService.instance.hasPendingRewards, isFalse);

        awards.failing = false;
        expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);
        expect(awards.amounts, [250]);
      },
    );

    test('a conversion awards 500 XP and is counted', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);
      final before = service.getReferralData();

      await service.simulateReferralConversion('Sam Rivera');

      final after = service.getReferralData();
      expect(awards.amounts, [500]);
      expect(after.convertedCount, before.convertedCount + 1);
      expect(after.totalReferredCount, before.totalReferredCount + 1);
      expect(after.totalXpEarned, before.totalXpEarned + 500);
      expect(after.referredUserIds, contains('usr_sam_rivera'));
    });

    test(
      'a failed conversion award records nothing; the retry counts once',
      () async {
        final awards = _Awards()..failing = true;
        final service = ReferralService(awardXp: awards.call);
        final before = service.getReferralData();

        await expectLater(
          service.simulateReferralConversion('Sam Rivera'),
          throwsA(isA<StateError>()),
        );
        expect(service.getReferralData().convertedCount, before.convertedCount);
        expect(service.getReferralData().totalXpEarned, before.totalXpEarned);

        awards.failing = false;
        await service.simulateReferralConversion('Sam Rivera');
        expect(awards.amounts, [500]);
        expect(
          service.getReferralData().convertedCount,
          before.convertedCount + 1,
        );
      },
    );
  });

  group('the shared default and the provider', () {
    test('with no provider the XP is saved to the athlete', () async {
      expect(BonusXp.awarder, same(BonusXp.saveOnly));
      final xpBefore = LocalStorage.getUserProgress().totalXP;

      await ReferralService().claimReferralCode('ATLAS-FRIEND1');

      expect(LocalStorage.getUserProgress().totalXP - xpBefore, 250);
      expect(
        LocalStorage.getUserXP(userId: BonusXp.defaultUserId).totalXP,
        250,
      );
    });

    test('a provider takes over the awards and refreshes its state', () async {
      final provider = FitnessProvider.instance;
      var notified = 0;
      provider.addListener(() => notified++);
      final before = provider.userProgress.totalXP;

      await ReferralService().claimReferralCode('ATLAS-FRIEND1');

      expect(provider.userProgress.totalXP - before, 250);
      expect(LocalStorage.getUserProgress().totalXP - before, 250);
      expect(notified, greaterThan(0));
    });

    test(
      'a service built before the provider uses it once it exists',
      () async {
        final service = ReferralService();
        final provider = FitnessProvider.instance;
        final before = provider.userProgress.totalXP;
        await service.claimReferralCode('ATLAS-FRIEND1');
        expect(provider.userProgress.totalXP - before, 250);
      },
    );

    test('after the provider is disposed the awards are still saved', () async {
      FitnessProvider.instance;
      FitnessProvider.resetInstance();
      expect(BonusXp.awarder, same(BonusXp.saveOnly));
      final before = LocalStorage.getUserProgress().totalXP;

      await ReferralService().claimReferralCode('ATLAS-FRIEND1');

      expect(LocalStorage.getUserProgress().totalXP - before, 250);
    });

    test('a provider created after a reset takes over the awards', () async {
      final first = FitnessProvider.instance;
      expect(first, isNotNull);
      FitnessProvider.resetInstance();
      final second = FitnessProvider.instance;
      expect(BonusXp.awarder, isNot(same(BonusXp.saveOnly)));
      final before = second.userProgress.totalXP;
      await ReferralService().claimReferralCode('ATLAS-FRIEND1');
      expect(second.userProgress.totalXP - before, 250);
    });
  });
}
