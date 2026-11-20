import 'dart:async';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/app_user.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/gamification/bonus_xp.dart';
import 'package:atlas/services/referral_service.dart';
import 'package:atlas/services/reward_queue_service.dart';
import 'package:atlas/widgets/social/referral_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the XP it is asked to award; can be told to fail or to wait.
class _Awards {
  final List<int> amounts = [];
  bool failing = false;
  Completer<void>? hold;
  void Function()? onCall;

  Future<void> call(int amount) async {
    onCall?.call();
    if (hold != null) await hold!.future;
    if (failing) throw StateError('award failed');
    amounts.add(amount);
  }
}

/// The per-athlete XP records that exist. (Reading an athlete with no record
/// falls back to a shared legacy record, so existence is what shows who got XP.)
Future<Set<String>> _xpRecords() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getKeys().where((k) => k.startsWith('user_xp_')).toSet();
}

AppUser _user(String id) =>
    AppUser(id: id, email: '$id@example.com', displayName: 'Athlete');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.clearAppUser();
    CloudSession.debugUserIdOverride = null;
    FitnessProvider.resetInstance();
    RewardQueueService.resetInstance();
    ReferralService.resetInstance();
    BonusXp.awarder = BonusXp.saveOnly;
  });

  tearDown(() async {
    CloudSession.debugUserIdOverride = null;
    await LocalStorage.clearAppUser();
    FitnessProvider.resetInstance();
    BonusXp.awarder = BonusXp.saveOnly;
  });

  group('a referral code can be claimed once per account', () {
    test('a repeat is refused and awards nothing', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);
      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isFalse);
      // The same code written differently is the same code.
      expect(await service.claimReferralCode('  atlas-friend1 '), isFalse);

      expect(awards.amounts, [250]);
    });

    test('a different code is a different claim', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);
      expect(await service.claimReferralCode('ATLAS-FRIEND2'), isTrue);

      expect(awards.amounts, [250, 250]);
    });

    test('the claim is remembered across a restart', () async {
      final first = ReferralService(awardXp: _Awards().call);
      expect(await first.claimReferralCode('ATLAS-FRIEND1'), isTrue);

      // A new service, as after the app is reopened.
      final awards = _Awards();
      final second = ReferralService(awardXp: awards.call);
      expect(await second.claimReferralCode('ATLAS-FRIEND1'), isFalse);
      expect(awards.amounts, isEmpty);
      expect(
        LocalStorage.hasClaimedReferralCode('usr_local', 'ATLAS-FRIEND1'),
        isTrue,
      );
    });

    test('two claims at the same moment award once', () async {
      final awards = _Awards()..hold = Completer<void>();
      final service = ReferralService(awardXp: awards.call);

      final a = service.claimReferralCode('ATLAS-FRIEND1');
      final b = service.claimReferralCode('ATLAS-FRIEND1');
      awards.hold!.complete();
      final results = await Future.wait([a, b]);

      expect(results.where((r) => r), hasLength(1));
      expect(awards.amounts, [250]);
    });

    test('two services claiming at the same moment still award once', () async {
      // The durable record, not just one service object's memory, decides.
      final awards = _Awards();
      final first = ReferralService(awardXp: awards.call);
      final second = ReferralService(awardXp: awards.call);

      expect(await first.claimReferralCode('ATLAS-FRIEND1'), isTrue);
      expect(await second.claimReferralCode('ATLAS-FRIEND1'), isFalse);
      expect(awards.amounts, [250]);
    });

    test('the claim is saved before the XP is awarded', () async {
      final awards = _Awards();
      var savedAtAward = false;
      awards.onCall = () => savedAtAward = LocalStorage.hasClaimedReferralCode(
        'usr_local',
        'ATLAS-FRIEND1',
      );
      await ReferralService(
        awardXp: awards.call,
      ).claimReferralCode('ATLAS-FRIEND1');
      expect(savedAtAward, isTrue);
    });

    test(
      'a failed award leaves nothing claimed, and the retry pays once',
      () async {
        final awards = _Awards()..failing = true;
        final service = ReferralService(awardXp: awards.call);

        await expectLater(
          service.claimReferralCode('ATLAS-FRIEND1'),
          throwsA(isA<StateError>()),
        );
        expect(
          LocalStorage.hasClaimedReferralCode('usr_local', 'ATLAS-FRIEND1'),
          isFalse,
        );
        expect(RewardQueueService.instance.hasPendingRewards, isFalse);

        awards.failing = false;
        expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);
        expect(await service.claimReferralCode('ATLAS-FRIEND1'), isFalse);
        expect(awards.amounts, [250]);
      },
    );

    test('invalid codes and your own code leave no claim behind', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);
      await service.claimReferralCode('nope');
      await service.claimReferralCode(service.getReferralData().referralCode);
      expect(awards.amounts, isEmpty);
      expect(LocalStorage.hasClaimedReferralCode('usr_local', 'NOPE'), isFalse);
    });

    test('each account has its own claims', () async {
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      await LocalStorage.saveAppUser(_user('user_a'));
      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);
      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isFalse);

      await LocalStorage.saveAppUser(_user('user_b'));
      expect(await service.claimReferralCode('ATLAS-FRIEND1'), isTrue);

      expect(awards.amounts, [250, 250]);
      expect(
        LocalStorage.hasClaimedReferralCode('user_a', 'ATLAS-FRIEND1'),
        isTrue,
      );
      expect(
        LocalStorage.hasClaimedReferralCode('user_b', 'ATLAS-FRIEND1'),
        isTrue,
      );
    });
  });

  group('who the default award goes to', () {
    test('with nobody signed in it is the local athlete', () async {
      expect(BonusXp.currentUserId(), 'usr_local');
      await BonusXp.saveOnly(100);
      expect(LocalStorage.getUserXP(userId: 'usr_local').totalXP, 100);
      expect(await _xpRecords(), {'user_xp_usr_local'});
    });

    test('a signed-in athlete gets their own XP, not the local one', () async {
      await LocalStorage.saveAppUser(_user('user_a'));
      expect(BonusXp.currentUserId(), 'user_a');

      await BonusXp.saveOnly(250);

      expect(LocalStorage.getUserXP(userId: 'user_a').totalXP, 250);
      // Only the signed-in athlete has a record: nothing went to the local one.
      expect(await _xpRecords(), {'user_xp_user_a'});
    });

    test(
      'a signed-in cloud account that matches the stored one is used',
      () async {
        await LocalStorage.saveAppUser(_user('user_a'));
        CloudSession.debugUserIdOverride = () => 'user_a';
        expect(BonusXp.currentUserId(), 'user_a');
      },
    );

    test('a cloud account that is not the stored one is refused', () async {
      await LocalStorage.saveAppUser(_user('user_a'));
      CloudSession.debugUserIdOverride = () => 'user_b';
      final progress = LocalStorage.getUserProgress().toJson();

      await expectLater(
        BonusXp.saveOnly(250),
        throwsA(isA<XpIdentityException>()),
      );

      expect(await _xpRecords(), isEmpty, reason: 'nobody was given XP');
      expect(LocalStorage.getUserProgress().toJson(), progress);
    });

    test('a cloud account with nothing stored is refused too', () async {
      CloudSession.debugUserIdOverride = () => 'user_b';
      await expectLater(
        BonusXp.saveOnly(250),
        throwsA(isA<XpIdentityException>()),
      );
      expect(await _xpRecords(), isEmpty);
    });

    test('a claim that cannot tell the account claims nothing', () async {
      await LocalStorage.saveAppUser(_user('user_a'));
      CloudSession.debugUserIdOverride = () => 'user_b';
      final awards = _Awards();
      final service = ReferralService(awardXp: awards.call);

      await expectLater(
        service.claimReferralCode('ATLAS-FRIEND1'),
        throwsA(isA<XpIdentityException>()),
      );
      expect(awards.amounts, isEmpty);
      expect(
        LocalStorage.hasClaimedReferralCode('user_a', 'ATLAS-FRIEND1'),
        isFalse,
      );
    });

    test(
      'the provider-backed award is unchanged and the default returns',
      () async {
        await LocalStorage.saveAppUser(_user('user_a'));
        final provider = FitnessProvider.instance;
        expect(BonusXp.awarder, isNot(same(BonusXp.saveOnly)));
        final before = provider.userProgress.totalXP;

        await provider.addXP(250);
        expect(provider.userProgress.totalXP - before, 250);

        FitnessProvider.resetInstance();
        expect(BonusXp.awarder, same(BonusXp.saveOnly));
        // With the provider gone the default still goes to the stored athlete.
        await BonusXp.saveOnly(100);
        expect(
          LocalStorage.getUserXP(userId: 'user_a').totalXP,
          greaterThan(0),
        );
      },
    );
  });

  group('ReferralCard', () {
    Future<void> pumpCard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: ReferralCard()),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> redeem(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.pump();
      await tester.tap(find.text('REDEEM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('claims, then says a repeat is a duplicate', (tester) async {
      final awards = _Awards();
      BonusXp.awarder = awards.call;
      await pumpCard(tester);

      await redeem(tester, 'ATLAS-FRIEND1');
      expect(find.textContaining('Claimed'), findsOneWidget);

      await redeem(tester, 'ATLAS-FRIEND1');
      expect(find.text('Invalid or duplicate referral code.'), findsOneWidget);
      expect(awards.amounts, [250]);
    });

    testWidgets('a failed award does not leave the card stuck', (tester) async {
      final awards = _Awards()..failing = true;
      BonusXp.awarder = awards.call;
      await pumpCard(tester);

      await redeem(tester, 'ATLAS-FRIEND1');

      expect(find.textContaining('Could not claim'), findsOneWidget);
      // Not loading, and the button works again.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('REDEEM'), findsOneWidget);

      awards.failing = false;
      await redeem(tester, 'ATLAS-FRIEND1');
      expect(find.textContaining('Claimed'), findsOneWidget);
      expect(awards.amounts, [250]);
    });

    testWidgets('an unknown account shows the same retry message', (
      tester,
    ) async {
      await LocalStorage.saveAppUser(_user('user_a'));
      CloudSession.debugUserIdOverride = () => 'user_b';
      final awards = _Awards();
      BonusXp.awarder = awards.call;
      await pumpCard(tester);

      await redeem(tester, 'ATLAS-FRIEND1');

      expect(find.textContaining('Could not claim'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(awards.amounts, isEmpty);
    });
  });
}
