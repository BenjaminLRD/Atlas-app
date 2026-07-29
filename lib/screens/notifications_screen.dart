import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _notificationService;
  late List<Map<String, dynamic>> _notifications;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _notifications = _notificationService.getNotifications();
  }

  void _markAllAsRead() {
    setState(() {
      _notificationService.markAllAsRead(_notifications);
    });
  }

  void _removeNotification(String id) {
    setState(() {
      _notificationService.removeNotification(_notifications, id);
    });
  }

  void _toggleNotificationReadStatus(String id, bool isCurrentlyRead) {
    setState(() {
      _notificationService.toggleReadStatus(_notifications, id, isCurrentlyRead);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all as read'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.outline),
                  SizedBox(height: 16),
                  Text('No notifications yet'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isUnread = !notification['isRead'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: isUnread
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUnread
                            ? AppColors.primaryContainer.withValues(alpha: 0.3)
                            : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications, size: 20),
                    ),
                    title: Text(
                      notification['title'] ?? '',
                      style: AppTheme.bodyMd.copyWith(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        color: AppColors.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification['body'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: AppColors.outline),
                            const SizedBox(width: 4),
                            Text(
                              notification['timestamp'] ?? '',
                              style: AppTheme.labelCaps.copyWith(
                                fontSize: 10,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _toggleNotificationReadStatus(
                              notification['id'] as String,
                              notification['isRead'] as bool),
                          icon: Icon(
                            notification['isRead']
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: notification['isRead']
                                ? AppColors.outline
                                : AppColors.primary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () => _removeNotification(notification['id'] as String),
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
