import '../models/notification_model.dart';
import 'notification_repository.dart';

/// High-level service for managing notifications and read statuses.
class NotificationService {
  final NotificationRepository _repository;

  NotificationService([NotificationRepository? repository])
      : _repository = repository ?? LocalNotificationRepository();

  /// Get list of notifications as strongly typed NotificationModel objects
  List<NotificationModel> getNotifications() {
    return _repository.getNotifications();
  }

  /// Persist updated notification list
  Future<void> saveNotifications(List<NotificationModel> list) async {
    await _repository.saveNotifications(list);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(List<NotificationModel> notifications) async {
    final updated = notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    await _repository.saveNotifications(updated);
  }

  /// Remove a single notification by id
  Future<void> removeNotification(
      List<NotificationModel> notifications, String id) async {
    final updated = notifications.where((n) => n.id != id).toList();
    await _repository.saveNotifications(updated);
  }

  /// Toggle read status for a single notification
  Future<void> toggleReadStatus(
      List<NotificationModel> notifications, String id, bool isCurrentlyRead) async {
    final updated = notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: !isCurrentlyRead);
      }
      return n;
    }).toList();
    await _repository.saveNotifications(updated);
  }

  /// Check if there are any unread notifications
  bool hasUnreadNotifications() {
    return _repository.hasUnreadNotifications();
  }
}
