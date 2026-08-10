import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/friend_challenge.dart';
import 'package:aizawl_gym/models/gym_community_event.dart';
import 'package:aizawl_gym/models/notification_item.dart';
import 'package:aizawl_gym/models/referral.dart';
import 'package:aizawl_gym/models/reward_event.dart';
import 'package:aizawl_gym/services/community_event_service.dart';
import 'package:aizawl_gym/services/friend_challenge_service.dart';
import 'package:aizawl_gym/services/growth_analytics_service.dart';
import 'package:aizawl_gym/services/leaderboard_service.dart';
import 'package:aizawl_gym/services/notification_service.dart';
import 'package:aizawl_gym/services/referral_service.dart';
import 'package:aizawl_gym/services/reward_queue_service.dart';
import 'package:aizawl_gym/services/social_service.dart';
import 'package:aizawl_gym/widgets/social/community_event_card.dart';
import 'package:aizawl_gym/widgets/social/friend_challenge_card.dart';
import 'package:aizawl_gym/widgets/social/referral_card.dart';
import 'package:aizawl_gym/widgets/social/workout_share_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RewardQueueService.resetInstance();
    ReferralService.resetInstance();
    FriendChallengeService.resetInstance();
    CommunityEventService.resetInstance();
    GrowthAnalyticsService.resetInstance();
    SocialService.resetInstance();
  });

  group('1. Referral System & Referral Rewards', () {
    test('ReferralData initial state generates AIRZAWL prefix code', () {
      final data = ReferralData.initial(userId: 'usr_local');
      expect(data.referralCode, startsWith('AIRZAWL-'));
      expect(data.totalReferredCount, equals(2));
      expect(data.convertedCount, equals(1));
    });

    test('ReferralService validates code format correctly', () {
      final service = ReferralService.instance;
      expect(service.isValidCode('AIRZAWL-ALEX123'), isTrue);
      expect(service.isValidCode('INVALID'), isFalse);
    });

    test('ReferralService.claimReferralCode grants bonus and enqueues RewardEvent', () async {
      final service = ReferralService.instance;
      final result = await service.claimReferralCode('AIRZAWL-MAYA999');

      expect(result, isTrue);

      final queue = RewardQueueService.instance;
      expect(queue.hasPendingRewards, isTrue);
      final reward = queue.peek();
      expect(reward?.type, equals(RewardType.referralReward));
    });

    test('ReferralService.simulateReferralConversion updates stats and enqueues +500 XP reward', () async {
      final service = ReferralService.instance;
      await service.simulateReferralConversion('Zorina');

      final updated = service.getReferralData();
      expect(updated.convertedCount, equals(2));
      expect(updated.totalXpEarned, equals(1000));

      final queue = RewardQueueService.instance;
      expect(queue.hasPendingRewards, isTrue);
    });
  });

  group('2. Friend Challenges System', () {
    test('FriendChallenge model percentage calculations', () {
      final challenge = FriendChallenge(
        id: 'c_1',
        creatorId: 'usr_local',
        creatorName: 'You',
        opponentId: 'usr_alex',
        opponentName: 'Alex',
        type: ChallengeType.volumeShowdown,
        title: 'Volume Battle',
        description: 'First to 10k',
        creatorProgress: 5000,
        opponentProgress: 7500,
        targetGoal: 10000,
      );

      expect(challenge.creatorPercentage, equals(0.5));
      expect(challenge.opponentPercentage, equals(0.75));
      expect(challenge.isCompleted, isFalse);
    });

    test('FriendChallengeService creates challenge and triggers notification', () async {
      final service = FriendChallengeService.instance;
      final newChallenge = service.createChallenge(
        opponentId: 'usr_maya',
        opponentName: 'Maya Chen',
        type: ChallengeType.streakSprint,
        title: '7-Day Streak Sprint',
        targetGoal: 7,
      );

      expect(newChallenge.opponentName, equals('Maya Chen'));
      expect(service.getChallenges().length, greaterThanOrEqualTo(3));

      final notifs = await NotificationService.instance.getNotifications();
      expect(notifs.any((n) => n.type == 'challenge'), isTrue);
    });

    test('FriendChallengeService updates progress and awards victory on goal completion', () {
      final service = FriendChallengeService.instance;
      service.updateProgressOnWorkout(volumeLifted: 6000);

      final queue = RewardQueueService.instance;
      expect(queue.hasPendingRewards, isTrue);
    });
  });

  group('3. Gym Community Events System', () {
    test('GymCommunityEvent model calculates remaining days and progress percentage', () {
      final event = GymCommunityEvent(
        id: 'ev_1',
        title: 'Aizawl Rally',
        description: 'Lift 1M kg',
        currentProgress: 500000,
        targetGoal: 1000000,
      );

      expect(event.progressPercentage, equals(0.5));
      expect(event.remainingDays, greaterThan(0));
    });

    test('CommunityEventService allows joining event and updating progress', () {
      final service = CommunityEventService.instance;
      service.joinEvent('event_2');

      final events = service.getEvents();
      final joined = events.firstWhere((e) => e.id == 'event_2');
      expect(joined.isJoined, isTrue);

      service.updateProgressOnWorkout(5000);
    });
  });

  group('4. Activity Feed Reactions & Comments', () {
    test('SocialService toggles reaction on activity item correctly', () async {
      final service = SocialService.instance;
      final feed = await service.getActivityFeed();
      final firstId = feed.first.id;

      await service.toggleReaction(firstId, 'fire');
      final updatedFeed = await service.getActivityFeed();
      final updatedItem = updatedFeed.firstWhere((a) => a.id == firstId);

      expect(updatedItem.userReaction, equals('fire'));

      await service.addComment(firstId);
    });
  });

  group('5. Expanded Leaderboard Filters', () {
    test('LeaderboardService retrieves filtered leaderboards by scope', () async {
      final service = LeaderboardService();
      final global = await service.getFilteredLeaderboard(scope: 'Global', metric: 'Total XP');
      expect(global.isNotEmpty, isTrue);

      final local = await service.getFilteredLeaderboard(scope: 'Local Gym', metric: 'Volume');
      expect(local.isNotEmpty, isTrue);

      final friends = await service.getFilteredLeaderboard(scope: 'Friends', metric: 'Workouts');
      expect(friends.isNotEmpty, isTrue);
    });
  });

  group('6. Social Notifications', () {
    test('NotificationItem social factory constructors set correct metadata', () {
      final n1 = NotificationItem.friendRequest(fromUserName: 'Zorina');
      expect(n1.type, equals('friend'));
      expect(n1.message, contains('Zorina'));

      final n2 = NotificationItem.challengeReceived(fromUserName: 'Alex', challengeTitle: 'Leg Day Showdown');
      expect(n2.type, equals('challenge'));

      final n3 = NotificationItem.referralConverted(friendName: 'Maya', xpReward: 500);
      expect(n3.type, equals('referral'));
    });
  });

  group('7. Growth Analytics Service', () {
    test('GrowthAnalyticsService tracks KPIs accurately', () {
      final analytics = GrowthAnalyticsService.instance;
      analytics.trackReferralSent();
      analytics.trackReferralConverted();
      analytics.trackSocialShare();
      analytics.trackCommunityInteraction();
      analytics.trackChallengeJoined();
      analytics.trackChallengeWon();

      final metrics = analytics.getGrowthMetrics();
      expect(metrics['referralsSent'], greaterThan(4));
      expect(metrics['referralsConverted'], greaterThan(2));
      expect(metrics['socialShares'], greaterThan(8));
      expect(metrics['communityInteractions'], greaterThan(29));
    });
  });

  group('8. Social Growth UI Widgets', () {
    testWidgets('WorkoutShareCard renders workout stats cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutShareCard(
              workoutTitle: 'Leg Day Hypertrophy',
              durationMinutes: 45,
              exercisesCompleted: 6,
              totalVolumeKg: 8500,
              caloriesBurned: 350,
              xpEarned: 450,
              personalRecords: ['Squats: 120kg'],
              theme: ShareCardTheme.cyberpunkNeon,
            ),
          ),
        ),
      );

      expect(find.text('AIZAWL GYM'), findsOneWidget);
      expect(find.text('Leg Day Hypertrophy'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('8500 kg'), findsOneWidget);
    });

    testWidgets('ReferralCard renders referral code and copy button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReferralCard(),
            ),
          ),
        ),
      );

      expect(find.text('REFERRAL PROGRAM'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('REDEEM'), findsOneWidget);
    });

    testWidgets('FriendChallengeCard renders 1v1 challenges', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FriendChallengeCard(),
            ),
          ),
        ),
      );

      expect(find.text('1V1 FRIEND CHALLENGES'), findsOneWidget);
    });

    testWidgets('CommunityEventCard renders active gym rally progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityEventCard(),
            ),
          ),
        ),
      );

      expect(find.text('GYM COMMUNITY RALLY'), findsOneWidget);
      expect(find.text('Aizawl Monsoon Fitness Rally'), findsOneWidget);
    });
  });
}
