import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/notification_service.dart';
import '../models/notification_model.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_list_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _notificationService;
  late List<NotificationModel> _notifications;

  @override
  void initState() {
    super.initState();
    _notificationService = AppDependencies.instance.notificationService;
    _notifications = _notificationService.getNotifications();
    _notificationService.markAllAsRead(_notifications);
    _notifications = _notificationService.getNotifications();
  }

  void _markAllAsRead() {
    setState(() {
      _notificationService.markAllAsRead(_notifications);
      _notifications = _notificationService.getNotifications();
    });
  }

  void _removeNotification(String id) {
    setState(() {
      _notificationService.removeNotification(_notifications, id);
      _notifications = _notificationService.getNotifications();
    });
  }

  void _toggleNotificationReadStatus(String id, bool isCurrentlyRead) {
    setState(() {
      _notificationService.toggleReadStatus(
        _notifications,
        id,
        isCurrentlyRead,
      );
      _notifications = _notificationService.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'Notifications',
        subtitle: unreadCount > 0
            ? '$unreadCount unread alerts'
            : 'All caught up',
        onBackTap: () => Navigator.maybePop(context),
        trailing: unreadCount > 0
            ? AppButton.text(
                label: 'Mark all read',
                icon: Icons.done_all,
                onPressed: _markAllAsRead,
              )
            : null,
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.outline,
                  ),
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
                final isUnread = !notification.isRead;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    borderColor: isUnread
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AppListTile(
                      leadingIcon: Icons.notifications,
                      iconColor: isUnread
                          ? AppColors.primary
                          : AppColors.outline,
                      title: notification.title,
                      subtitle: notification.body,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _toggleNotificationReadStatus(
                              notification.id,
                              notification.isRead,
                            ),
                            icon: Icon(
                              notification.isRead
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: notification.isRead
                                  ? AppColors.outline
                                  : AppColors.primary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () =>
                                _removeNotification(notification.id),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.error,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
