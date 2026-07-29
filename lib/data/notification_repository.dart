import '../models/notification_model.dart';
import 'local_storage.dart';

/// Abstract interface for notification persistence operations.
abstract class NotificationRepository {
  List<NotificationModel> getNotifications();
  Future<void> saveNotifications(List<NotificationModel> list);
  bool hasUnreadNotifications();
}

/// Default local implementation of NotificationRepository backed by LocalStorage.
class LocalNotificationRepository implements NotificationRepository {
  @override
  List<NotificationModel> getNotifications() {
    return LocalStorage.getNotificationModels();
  }

  @override
  Future<void> saveNotifications(List<NotificationModel> list) async {
    await LocalStorage.saveNotifications(list);
  }

  @override
  bool hasUnreadNotifications() {
    final notifications = getNotifications();
    return notifications.any((n) => !n.isRead);
  }
}
