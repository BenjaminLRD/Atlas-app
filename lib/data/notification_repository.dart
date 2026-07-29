import '../models/notification_model.dart';
import 'local_storage.dart';

/// Abstract interface for notification persistence operations.
abstract class NotificationRepository {
  List<NotificationModel> getNotificationModels();
  List<Map<String, dynamic>> getNotifications();
  Future<void> saveNotifications(dynamic list);
  bool hasUnreadNotifications();
}

/// Default local implementation of NotificationRepository backed by LocalStorage.
class LocalNotificationRepository implements NotificationRepository {
  @override
  List<NotificationModel> getNotificationModels() {
    return LocalStorage.getNotificationModels();
  }

  @override
  List<Map<String, dynamic>> getNotifications() {
    return LocalStorage.getNotifications();
  }

  @override
  Future<void> saveNotifications(dynamic list) async {
    await LocalStorage.saveNotifications(list);
  }

  @override
  bool hasUnreadNotifications() {
    final notifications = getNotifications();
    return notifications.any((n) => n['isRead'] == false);
  }
}
