import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_xp.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/gamification/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XPService xpService;
  late GamificationService gamificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    gamificationService = GamificationService();
    xpService = XPService(gamificationService: gamificationService);
  });

  group('FitnessXP Constants & XP Sources Verification', () {
    test('FitnessXP sources match expected specifications', () {
      expect(FitnessXP.workoutCompleted, 100);
      expect(FitnessXP.personalRecord, 250);
      expect(FitnessXP.workoutStreakPerDay, 50);
      expect(FitnessXP.mealLogging, 20);
      expect(FitnessXP.communityContribution, 30);
      expect(FitnessXP.challengeCompletion, 500);
    });
  });

  group('UserXP Domain Model & Level Calculation Engine', () {
    test('UserXP.calculateLevel maps totalXP to 500 XP level milestones', () {
      expect(UserXP.calculateLevel(0), 1);
      expect(UserXP.calculateLevel(250), 1);
      expect(UserXP.calculateLevel(499), 1);
      expect(UserXP.calculateLevel(500), 2);
      expect(UserXP.calculateLevel(999), 2);
      expect(UserXP.calculateLevel(1000), 3);
      expect(UserXP.calculateLevel(2450), 5);
      expect(UserXP.calculateLevel(5000), 11);
    });

    test('UserXP progression helpers compute accurate metrics', () {
      final userXP = UserXP(
        userId: 'usr_test_1',
        totalXP: 750,
        currentLevel: 2,
        weeklyXP: 750,
        monthlyXP: 750,
        lastUpdated: DateTime.now(),
      );

      expect(userXP.currentLevelBaseXP, 500);
      expect(userXP.xpForNextLevel, 1000);
      expect(userXP.xpWithinCurrentLevel, 250);
      expect(userXP.xpToNextLevel, 250);
      expect(userXP.levelProgressFraction, 0.5);
    });

    test('UserXP JSON serialization and roundtrip integrity', () {
      final now = DateTime.now();
      final original = UserXP(
        userId: 'usr_99',
        totalXP: 1850,
        currentLevel: 4,
        weeklyXP: 450,
        monthlyXP: 1850,
        lastUpdated: now,
      );

      final json = original.toJson();
      final restored = UserXP.fromJson(json);

      expect(restored.userId, 'usr_99');
      expect(restored.totalXP, 1850);
      expect(restored.currentLevel, 4);
      expect(restored.weeklyXP, 450);
      expect(restored.monthlyXP, 1850);
      expect(restored.xpToNextLevel, 150);
    });
  });

  group('XPService — Action Reward Dispatch & Level Progression', () {
    test(
      'awardWorkoutXP grants +100 base, +250 per PR, and +50 per streak day',
      () async {
        // 1. Basic Workout (+100 XP)
        final xp1 = await xpService.awardWorkoutXP(
          userId: 'usr_athlete',
          streakDays: 0,
          prCount: 0,
        );
        expect(xp1.totalXP, 100);
        expect(xp1.weeklyXP, 100);
        expect(xp1.currentLevel, 1);

        // 2. Workout with 2 PRs (+500) and 3-day streak (+150) + base 100 = +750 XP
        final xp2 = await xpService.awardWorkoutXP(
          userId: 'usr_athlete',
          streakDays: 3,
          prCount: 2,
        );
        expect(xp2.totalXP, 850); // 100 + 750
        expect(xp2.weeklyXP, 850);
        expect(xp2.currentLevel, 2); // Level 2 reached at 500+ XP
      },
    );

    test('awardPersonalRecordXP grants +250 XP per PR', () async {
      final result = await xpService.awardPersonalRecordXP(
        userId: 'usr_pr',
        count: 2,
      );
      expect(result.totalXP, 500);
      expect(result.currentLevel, 2);
    });

    test('awardStreakXP grants +50 XP per streak day', () async {
      final result = await xpService.awardStreakXP(
        userId: 'usr_streak',
        streakDays: 7,
      );
      expect(result.totalXP, 350);
    });

    test('awardMealLogXP grants +20 XP', () async {
      final result = await xpService.awardMealLogXP(userId: 'usr_nut');
      expect(result.totalXP, 20);
    });

    test('awardCommunityXP grants +30 XP', () async {
      final result = await xpService.awardCommunityXP(
        userId: 'usr_comm',
        activityType: 'post',
      );
      expect(result.totalXP, 30);
    });

    test('awardChallengeXP grants +500 XP and triggers level up', () async {
      final result = await xpService.awardChallengeXP(
        userId: 'usr_chal',
        challengeId: 'ch_weekly_bench',
      );
      expect(result.totalXP, 500);
      expect(result.currentLevel, 2);
    });

    test(
      'XPService broadcasts XPAwardEvent stream with didLevelUp detection',
      () async {
        final events = <XPAwardEvent>[];
        final subscription = xpService.xpEvents.listen(events.add);

        await xpService.awardXP(
          userId: 'usr_event',
          amount: 300,
          source: 'first_gain',
        );
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events.first.amount, 300);
        expect(events.first.didLevelUp, isFalse);
        expect(events.first.newLevel, 1);

        // Trigger level-up by adding +300 (total 600 -> Level 2)
        await xpService.awardXP(
          userId: 'usr_event',
          amount: 300,
          source: 'level_up_gain',
        );
        await pumpEventQueue();

        expect(events.length, 2);
        expect(events[1].amount, 300);
        expect(events[1].didLevelUp, isTrue);
        expect(events[1].newLevel, 2);

        await subscription.cancel();
      },
    );

    test('XP awards synchronize with UserProgress in LocalStorage', () async {
      await xpService.awardWorkoutXP(
        userId: 'local_user',
        streakDays: 5,
        prCount: 1,
      ); // 100 + 250 + 250 = 600 XP

      final userProgress = LocalStorage.getUserProgress();
      expect(userProgress.totalXP, 600);
    });
  });

  group('FitnessProvider — Gamification 2.0 Integration Tests', () {
    test(
      'FitnessProvider exposes reactive UserXP and updates on XP actions',
      () async {
        final provider = FitnessProvider(
          gamificationService: gamificationService,
          xpService: xpService,
        );

        expect(provider.userXP.totalXP, 0);
        expect(provider.userXP.currentLevel, 1);

        // Award workout XP
        await provider.awardWorkoutXP(
          streakDays: 4,
          prCount: 1,
        ); // 100 + 250 + 200 = 550 XP

        expect(provider.userXP.totalXP, 550);
        expect(provider.userXP.currentLevel, 2);
        expect(provider.totalXP, 550);

        // Award meal logging XP
        await provider.awardMealLogXP(); // +20 XP
        expect(provider.userXP.totalXP, 570);

        // Award community XP
        await provider.awardCommunityXP(); // +30 XP
        expect(provider.userXP.totalXP, 600);

        // Award challenge XP
        await provider.awardChallengeXP(); // +500 XP
        expect(provider.userXP.totalXP, 1100);
        expect(provider.userXP.currentLevel, 3);
      },
    );
  });
}
