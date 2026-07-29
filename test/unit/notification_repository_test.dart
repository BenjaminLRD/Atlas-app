import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/data/notification_repository.dart';
import 'package:aizawl_gym/data/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NotificationRepository & NotificationService Tests', () {
    test('NotificationService retrieves default notifications and unread status', () {
      final repo = LocalNotificationRepository();
      final service = NotificationService(repo);

      final notifications = service.getNotifications();
      expect(notifications.isNotEmpty, isTrue);
      expect(service.hasUnreadNotifications(), isTrue);
    });

    test('NotificationService markAllAsRead updates all items to read', () async {
      final service = NotificationService();
      final notifications = service.getNotifications();

      await service.markAllAsRead(notifications);

      final updated = service.getNotifications();
      expect(updated.every((n) => n['isRead'] == true), isTrue);
      expect(service.hasUnreadNotifications(), isFalse);
    });

    test('NotificationService removeNotification removes target notification', () async {
      final service = NotificationService();
      final notifications = service.getNotifications();
      final targetId = notifications.first['id'] as String;

      await service.removeNotification(notifications, targetId);

      final updated = service.getNotifications();
      expect(updated.any((n) => n['id'] == targetId), isFalse);
    });

    test('NotificationService toggleReadStatus flips target notification read state', () async {
      final service = NotificationService();
      final notifications = service.getNotifications();
      final targetId = notifications.first['id'] as String;
      final initialRead = notifications.first['isRead'] as bool;

      await service.toggleReadStatus(notifications, targetId, initialRead);

      final updated = service.getNotifications();
      final item = updated.firstWhere((n) => n['id'] == targetId);
      expect(item['isRead'], equals(!initialRead));
    });
  });
}
