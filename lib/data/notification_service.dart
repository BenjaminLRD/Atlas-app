import '../models/notification_model.dart';
import 'notification_repository.dart';

/// High-level service for managing notifications and read statuses.
class NotificationService {
  final NotificationRepository _repository;

  NotificationService([NotificationRepository? repository])
      : _repository = repository ?? LocalNotificationRepository();

  /// Get list of notifications as maps for UI rendering
  List<Map<String, dynamic>> getNotifications() {
    return _repository.getNotifications();
  }

  /// Get list of notifications as strongly typed NotificationModel objects
  List<NotificationModel> getNotificationModels() {
    return _repository.getNotificationModels();
  }

  /// Persist updated notification list
  Future<void> saveNotifications(dynamic list) async {
    await _repository.saveNotifications(list);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(List<Map<String, dynamic>> notifications) async {
    for (var n in notifications) {
      n['isRead'] = true;
    }
    await _repository.saveNotifications(notifications);
  }

  /// Remove a single notification by id
  Future<void> removeNotification(
      List<Map<String, dynamic>> notifications, String id) async {
    notifications.removeWhere((n) => n['id'] == id);
    await _repository.saveNotifications(notifications);
  }

  /// Toggle read status for a single notification
  Future<void> toggleReadStatus(
      List<Map<String, dynamic>> notifications, String id, bool isCurrentlyRead) async {
    final index = notifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      notifications[index]['isRead'] = !isCurrentlyRead;
      await _repository.saveNotifications(notifications);
    }
  }

  /// Check if there are any unread notifications
  bool hasUnreadNotifications() {
    return _repository.hasUnreadNotifications();
  }
}
