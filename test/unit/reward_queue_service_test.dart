import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/badge.dart';
import 'package:aizawl_gym/models/reward_event.dart';
import 'package:aizawl_gym/services/reward_queue_service.dart';
import 'package:aizawl_gym/widgets/common/rank_up_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardEvent Tests', () {
    test('creates RankUp RewardEvent with correct priority and id', () {
      const details = RankUpDetails(
        previousRank: 'Bronze I',
        newRank: 'Silver IV',
        xpGained: 250,
        message: 'Congrats!',
      );

      final event = RewardEvent.rankUp(details);

      expect(event.type, equals(RewardType.rankUp));
      expect(event.priority, equals(100));
      expect(event.id, equals('rank_up_Silver IV'));
      expect(event.data, equals(details));
    });

    test('creates Achievement RewardEvent with correct priority and id', () {
      const badge = AchievementBadge(
        id: 'streak_7',
        title: '7 Day Streak',
        description: 'Completed 7 days in a row',
        iconCodePoint: 0xe625,
        category: 'Streak',
        rarity: 'Epic',
      );

      final event = RewardEvent.achievement(badge);

      expect(event.type, equals(RewardType.achievement));
      expect(event.priority, equals(80));
      expect(event.id, equals('achievement_streak_7'));
      expect(event.data, equals(badge));
    });

    test('creates XP Bonus RewardEvent with correct priority', () {
      final event = RewardEvent.xpBonus(
        amount: 150,
        source: 'Leg Day',
        customId: 'xp_leg_day_01',
      );

      expect(event.type, equals(RewardType.xpBonus));
      expect(event.priority, equals(50));
      expect(event.id, equals('xp_leg_day_01'));
    });
  });

  group('RewardQueueService Tests', () {
    late RewardQueueService queueService;

    setUp(() {
      RewardQueueService.resetInstance();
      queueService = RewardQueueService.instance;
      queueService.clearQueue();
    });

    test('maintains priority queue order correctly', () {
      const details = RankUpDetails(
        previousRank: 'Bronze I',
        newRank: 'Silver IV',
        xpGained: 250,
        message: 'Congrats!',
      );
      const badge = AchievementBadge(
        id: 'first_workout',
        title: 'First Step',
        description: 'Completed first workout',
        iconCodePoint: 0xe625,
        category: 'Milestone',
        rarity: 'Common',
      );
      final xpEvent = RewardEvent.xpBonus(
        amount: 100,
        source: 'Workout',
        customId: 'xp_test_01',
      );

      final rankEvent = RewardEvent.rankUp(details);
      final badgeEvent = RewardEvent.achievement(badge);

      // Enqueue out of order (XP -> Achievement -> RankUp)
      queueService.enqueue(xpEvent);
      queueService.enqueue(badgeEvent);
      queueService.enqueue(rankEvent);

      expect(queueService.pendingCount, equals(3));

      // Dequeue should return in priority order: RankUp (100) -> Achievement (80) -> XP Bonus (50)
      final first = queueService.dequeue();
      expect(first?.type, equals(RewardType.rankUp));

      final second = queueService.dequeue();
      expect(second?.type, equals(RewardType.achievement));

      final third = queueService.dequeue();
      expect(third?.type, equals(RewardType.xpBonus));

      expect(queueService.hasPendingRewards, isFalse);
    });

    test('prevents duplicate reward events from being queued', () {
      final event1 = RewardEvent.xpBonus(
        amount: 100,
        source: 'Workout',
        customId: 'dup_test_01',
      );

      final eventDuplicate = RewardEvent.xpBonus(
        amount: 100,
        source: 'Workout',
        customId: 'dup_test_01',
      );

      final added1 = queueService.enqueue(event1);
      final added2 = queueService.enqueue(eventDuplicate);

      expect(added1, isTrue);
      expect(added2, isFalse);
      expect(queueService.pendingCount, equals(1));
    });

    test('prevents dequeued/processed rewards from being re-enqueued', () {
      final event = RewardEvent.xpBonus(
        amount: 50,
        source: 'Daily',
        customId: 'unique_xp_1',
      );

      queueService.enqueue(event);
      final dequeued = queueService.dequeue();
      expect(dequeued?.id, equals('unique_xp_1'));

      // Try re-enqueuing the exact same event
      final reAddSuccess = queueService.enqueue(event);
      expect(reAddSuccess, isFalse);
      expect(queueService.pendingCount, equals(0));
    });
  });
}
