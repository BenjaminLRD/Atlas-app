import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/notification_item.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/notification_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    NotificationService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('NotificationItem Model Unit Tests', () {
    test('NotificationItem serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final item = NotificationItem(
        id: 'n1',
        userId: 'usr_1',
        title: 'Rank Promoted!',
        message: 'Reached Gold I',
        type: 'rank_up',
        createdAt: now,
        isRead: false,
        actionRoute: '/ranked',
      );

      final json = item.toJson();
      expect(json['id'], equals('n1'));
      expect(json['type'], equals('rank_up'));
      expect(json['is_read'], isFalse);

      final parsed = NotificationItem.fromJson(json);
      expect(parsed.id, equals('n1'));
      expect(parsed.title, equals('Rank Promoted!'));

      final updated = item.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
    });
  });

  group('NotificationService Unit Tests', () {
    test('getNotifications returns initial default notifications', () async {
      final service = NotificationService.instance;
      final list = await service.getNotifications();

      expect(list, isNotEmpty);
      expect(list.any((n) => n.type == 'coach'), isTrue);
    });

    test('createNotification adds new notification and updates unread count', () async {
      final service = NotificationService.instance;
      final initialUnread = await service.getUnreadCount();

      await service.createNotification(
        NotificationItem(
          id: 'test_n1',
          userId: 'usr_local',
          title: 'Achievement Unlocked',
          message: 'Earned Bronze lifter',
          type: 'achievement',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      final newUnread = await service.getUnreadCount();
      expect(newUnread, equals(initialUnread + 1));
    });

    test('markAsRead updates notification state to read', () async {
      final service = NotificationService.instance;
      await service.createNotification(
        NotificationItem(
          id: 'n_mark_read',
          userId: 'usr_local',
          title: 'Test Notification',
          message: 'Read me',
          type: 'reminder',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      await service.markAsRead('n_mark_read');
      final list = await service.getNotifications();
      final item = list.firstWhere((n) => n.id == 'n_mark_read');
      expect(item.isRead, isTrue);
    });
  });

  group('FitnessProvider Notification Integration Tests', () {
    test('loadNotifications populates notifications list and unread count', () async {
      final provider = FitnessProvider.instance;
      await provider.loadNotifications();

      expect(provider.notifications, isNotEmpty);
      expect(provider.unreadNotificationCount, greaterThanOrEqualTo(1));
    });

    test('markNotificationRead updates provider notification state', () async {
      final provider = FitnessProvider.instance;
      await provider.loadNotifications();
      final unreadItem = provider.notifications.firstWhere((n) => !n.isRead);

      await provider.markNotificationRead(unreadItem.id);
      expect(provider.notifications.firstWhere((n) => n.id == unreadItem.id).isRead, isTrue);
    });

    test('saveWorkoutCompletion triggers rank promotion and achievement notifications', () async {
      final provider = FitnessProvider.instance;
      await provider.loadNotifications();

      for (int i = 0; i < 4; i++) {
        await provider.saveWorkoutCompletion(WorkoutHistory(
          workoutName: 'Prep Workout $i',
          dateCompleted: DateTime.now().subtract(Duration(days: 5 - i)),
          durationSeconds: 1800,
          exercisesCompleted: 3,
          completionPercentage: 1.0,
        ));
      }

      await provider.loadNotifications();
      final preCount = provider.notifications.length;

      final workout = WorkoutHistory(
        workoutName: 'Milestone Workout 5',
        dateCompleted: DateTime.now(),
        durationSeconds: 3600,
        exercisesCompleted: 8,
        completionPercentage: 1.0,
        totalVolume: 5000.0,
        caloriesBurned: 400.0,
        xpEarned: 1000,
      );

      await provider.saveWorkoutCompletion(workout);
      await provider.loadNotifications();

      expect(provider.notifications.length, greaterThan(preCount));
    });
  });
}
