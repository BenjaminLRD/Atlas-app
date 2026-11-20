import '../models/notification_item.dart';
import '../models/notification_model.dart';
import '../data/notification_repository.dart';
import 'supabase/supabase_client.dart';

/// Central unified service managing system notifications across achievements,
/// rank promotions, weekly challenges, AI Coach daily briefings, and social updates.
class NotificationService {
  static NotificationService? _instance;
  final SupabaseClientManager _clientManager;
  final NotificationRepository _repository;
  List<NotificationItem>? _cachedNotifications;

  NotificationService({
    SupabaseClientManager? clientManager,
    NotificationRepository? repository,
  }) : _clientManager = clientManager ?? SupabaseClientManager.instance,
       _repository = repository ?? LocalNotificationRepository();

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static NotificationService get instance {
    _instance ??= NotificationService();
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // REPOSITORY / NOTIFICATION MODEL METHODS
  // ---------------------------------------------------------------------------

  /// Get list of notifications as strongly typed NotificationModel objects from local repository
  List<NotificationModel> getModelNotifications() {
    return _repository.getNotifications();
  }

  /// Alias for getModelNotifications
  List<NotificationModel> getNotificationsSync() {
    return _repository.getNotifications();
  }

  /// Persist updated notification list to local repository
  Future<void> saveModelNotifications(List<NotificationModel> list) async {
    await _repository.saveNotifications(list);
  }

  /// Mark all local notifications as read
  Future<void> markAllAsRead(List<NotificationModel> notifications) async {
    final updated = notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _repository.saveNotifications(updated);
  }

  /// Remove a single local notification by id
  Future<void> removeNotification(
    List<NotificationModel> notifications,
    String id,
  ) async {
    final updated = notifications.where((n) => n.id != id).toList();
    await _repository.saveNotifications(updated);
  }

  /// Toggle read status for a single local notification
  Future<void> toggleReadStatus(
    List<NotificationModel> notifications,
    String id,
    bool isCurrentlyRead,
  ) async {
    final updated = notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: !isCurrentlyRead);
      }
      return n;
    }).toList();
    await _repository.saveNotifications(updated);
  }

  /// Check if there are any unread local notifications
  bool hasUnreadNotifications() {
    return _repository.hasUnreadNotifications();
  }

  // ---------------------------------------------------------------------------
  // ASYNC / SUPABASE / NOTIFICATION ITEM METHODS
  // ---------------------------------------------------------------------------

  static List<NotificationItem> _getDefaultNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'notif_1',
        userId: 'usr_local',
        title: 'Welcome to Atlas AI!',
        message:
            'Track workouts, claim weekly quests, and climb the competitive leaderboards.',
        type: 'coach',
        createdAt: now.subtract(const Duration(hours: 1)),
        isRead: false,
        actionRoute: '/home',
      ),
      NotificationItem(
        id: 'notif_2',
        userId: 'usr_local',
        title: 'Weekly Quests Unlocked',
        message:
            '5 new challenges are active for this week. Complete them to earn bonus XP!',
        type: 'challenge',
        createdAt: now.subtract(const Duration(hours: 3)),
        isRead: false,
        actionRoute: '/challenges',
      ),
    ];
  }

  /// Retrieve notification list for a user.
  Future<List<NotificationItem>> getNotifications({
    String userId = 'usr_local',
  }) async {
    if (_cachedNotifications != null) {
      return List.unmodifiable(_cachedNotifications!);
    }

    try {
      final query = _clientManager.from('notifications');
      final rows = await query.select('user_id', userId);
      if (rows.isNotEmpty) {
        final list = rows.map((r) => NotificationItem.fromJson(r)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _cachedNotifications = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}

    final defaults = _getDefaultNotifications();
    _cachedNotifications = List.from(defaults);
    return List.unmodifiable(defaults);
  }

  /// Retrieve total unread notification count.
  Future<int> getUnreadCount({String userId = 'usr_local'}) async {
    final list = await getNotifications(userId: userId);
    return list.where((n) => !n.isRead).length;
  }

  /// Create a new notification item.
  Future<void> createNotification(NotificationItem notification) async {
    final list = List<NotificationItem>.from(
      await getNotifications(userId: notification.userId),
    );

    // Prevent duplicate notifications with identical title and message created recently
    final isDuplicate = list.any(
      (n) =>
          n.title == notification.title &&
          n.message == notification.message &&
          n.createdAt.difference(notification.createdAt).abs().inMinutes < 5,
    );

    if (isDuplicate) return;

    list.insert(0, notification);
    _cachedNotifications = list;

    try {
      await _clientManager.from('notifications').insert(notification.toJson());
    } catch (_) {}
  }

  /// Mark specific notification as read.
  Future<void> markAsRead(String id, {String userId = 'usr_local'}) async {
    final list = List<NotificationItem>.from(
      await getNotifications(userId: userId),
    );
    final idx = list.indexWhere((n) => n.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isRead: true);
      _cachedNotifications = list;

      try {
        await _clientManager
            .from('notifications')
            .update({'is_read': true}, 'id', id);
      } catch (_) {}
    }
  }

  /// Clear all notifications for a user.
  Future<void> clearNotifications({String userId = 'usr_local'}) async {
    _cachedNotifications = [];
    try {
      await _clientManager.from('notifications').delete('user_id', userId);
    } catch (_) {}
  }
}
