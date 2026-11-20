import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/notification_repository.dart';
import 'package:atlas/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NotificationRepository & NotificationService Tests', () {
    test(
      'NotificationService retrieves default notifications and unread status',
      () {
        final repo = LocalNotificationRepository();
        final service = NotificationService(repository: repo);

        final notifications = service.getModelNotifications();
        expect(notifications.isNotEmpty, isTrue);
        expect(service.hasUnreadNotifications(), isTrue);
      },
    );

    test(
      'NotificationService markAllAsRead updates all items to read',
      () async {
        final service = NotificationService();
        final notifications = service.getModelNotifications();

        await service.markAllAsRead(notifications);

        final updated = service.getModelNotifications();
        expect(updated.every((n) => n.isRead == true), isTrue);
        expect(service.hasUnreadNotifications(), isFalse);
      },
    );

    test(
      'NotificationService removeNotification removes target notification',
      () async {
        final service = NotificationService();
        final notifications = service.getModelNotifications();
        final targetId = notifications.first.id;

        await service.removeNotification(notifications, targetId);

        final updated = service.getModelNotifications();
        expect(updated.any((n) => n.id == targetId), isFalse);
      },
    );

    test(
      'NotificationService toggleReadStatus flips target notification read state',
      () async {
        final service = NotificationService();
        final notifications = service.getModelNotifications();
        final targetId = notifications.first.id;
        final initialRead = notifications.first.isRead;

        await service.toggleReadStatus(notifications, targetId, initialRead);

        final updated = service.getModelNotifications();
        final item = updated.firstWhere((n) => n.id == targetId);
        expect(item.isRead, equals(!initialRead));
      },
    );
  });
}
