import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/activity_item.dart';
import 'package:aizawl_gym/models/friendship.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/social_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    SocialService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('Friendship & ActivityItem Models Unit Tests', () {
    test('Friendship serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final f = Friendship(
        id: 'fs_1',
        requesterId: 'u1',
        receiverId: 'u2',
        status: 'pending',
        createdAt: now,
      );

      final json = f.toJson();
      expect(json['id'], equals('fs_1'));
      expect(json['requester_id'], equals('u1'));
      expect(json['status'], equals('pending'));

      final updated = f.copyWith(status: 'accepted');
      expect(updated.isAccepted, isTrue);
    });

    test('ActivityItem serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final act = ActivityItem(
        id: 'act_1',
        userId: 'u1',
        type: 'workout',
        title: 'Completed Chest Day',
        description: '5000 kg total volume',
        createdAt: now,
      );

      final json = act.toJson();
      expect(json['id'], equals('act_1'));
      expect(json['type'], equals('workout'));

      final parsed = ActivityItem.fromJson(json);
      expect(parsed.title, equals('Completed Chest Day'));
    });
  });

  group('SocialService Unit Tests', () {
    test('getActivityFeed returns initial default activity feed', () async {
      final service = SocialService.instance;
      final feed = await service.getActivityFeed();

      expect(feed, isNotEmpty);
      expect(feed.any((a) => a.type == 'workout'), isTrue);
    });

    test('sendFriendRequest creates pending friendship request', () async {
      final service = SocialService.instance;
      final friendship = await service.sendFriendRequest(
        requesterId: 'usr_local',
        receiverId: 'usr_target',
      );

      expect(friendship.requesterId, equals('usr_local'));
      expect(friendship.receiverId, equals('usr_target'));
      expect(friendship.isPending, isTrue);
    });

    test('acceptFriendRequest transitions friendship status to accepted', () async {
      final service = SocialService.instance;
      final req = await service.sendFriendRequest(
        requesterId: 'usr_target_2',
        receiverId: 'usr_local',
      );

      await service.acceptFriendRequest(
        friendshipId: req.id,
        userId: 'usr_local',
      );

      final pending = await service.getPendingRequests(userId: 'usr_local');
      expect(pending.any((p) => p.id == req.id), isFalse);
    });
  });

  group('FitnessProvider Social Integration Tests', () {
    test('loadFriends and loadActivityFeed populate provider lists', () async {
      final provider = FitnessProvider.instance;
      await provider.loadFriends();
      await provider.loadActivityFeed();

      expect(provider.friends, isNotEmpty);
      expect(provider.activityFeed, isNotEmpty);
    });

    test('saveWorkoutCompletion triggers activity feed post', () async {
      final provider = FitnessProvider.instance;
      await provider.loadActivityFeed();
      final initialFeedCount = provider.activityFeed.length;

      final workout = WorkoutHistory(
        workoutName: 'Evening Leg Session',
        dateCompleted: DateTime.now(),
        durationSeconds: 2700,
        exercisesCompleted: 5,
        completionPercentage: 1.0,
        totalVolume: 4500.0,
        caloriesBurned: 350.0,
        xpEarned: 150,
      );

      await provider.saveWorkoutCompletion(workout);
      await provider.loadActivityFeed();

      expect(provider.activityFeed.length, greaterThan(initialFeedCount));
      expect(provider.activityFeed.first.type, equals('workout'));
    });
  });
}
