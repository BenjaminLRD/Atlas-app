import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/notification_item.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';

/// Notification Center Screen providing a unified feed for achievements,
/// rank promotions, weekly challenges, AI Coach briefings, and reminders.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final notifications = provider.notifications;
        final unreadCount = provider.unreadNotificationCount;

        final filtered = notifications.where((n) {
          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'unread') return !n.isRead;
          return n.type.toLowerCase() == _selectedFilter;
        }).toList();

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader.back(
                  title: 'Notifications',
                  subtitle: unreadCount > 0
                      ? '$unreadCount unread updates'
                      : 'All caught up!',
                  onBackTap: () => Navigator.of(context).pop(),
                  trailing: notifications.isNotEmpty
                      ? TextButton(
                          onPressed: () => _confirmClearAll(context, provider),
                          child: const Text('Clear All'),
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildFilterChips(context),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState(context)
                            : RefreshIndicator(
                                onRefresh: () => provider.loadNotifications(),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return _buildNotificationTile(context, item, provider);
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['all', 'unread', 'achievement', 'rank_up', 'challenge', 'coach'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          final label = filter == 'rank_up'
              ? 'Ranks'
              : filter[0].toUpperCase() + filter.substring(1);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : context.appTextPrimary,
              ),
              selectedColor: AppColors.primaryContainer,
              backgroundColor: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
              onSelected: (_) => setState(() => _selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationItem item,
    FitnessProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          if (!item.isRead) {
            provider.markNotificationRead(item.id);
          }
          if (item.actionRoute != null && item.actionRoute!.isNotEmpty) {
            Navigator.of(context).pushNamed(item.actionRoute!);
          }
        },
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(item.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimeAgo(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type.toLowerCase()) {
      case 'achievement':
        iconData = Icons.emoji_events_rounded;
        iconColor = Colors.amber;
        bgColor = Colors.amber.withValues(alpha: 0.15);
        break;
      case 'rank_up':
        iconData = Icons.military_tech_rounded;
        iconColor = AppColors.primaryContainer;
        bgColor = AppColors.primaryContainer.withValues(alpha: 0.15);
        break;
      case 'challenge':
        iconData = Icons.flag_rounded;
        iconColor = Colors.blue;
        bgColor = Colors.blue.withValues(alpha: 0.15);
        break;
      case 'friend':
        iconData = Icons.group_rounded;
        iconColor = Colors.purple;
        bgColor = Colors.purple.withValues(alpha: 0.15);
        break;
      case 'coach':
        iconData = Icons.auto_awesome_rounded;
        iconColor = Colors.teal;
        bgColor = Colors.teal.withValues(alpha: 0.15);
        break;
      case 'reminder':
      default:
        iconData = Icons.notifications_rounded;
        iconColor = Colors.orange;
        bgColor = Colors.orange.withValues(alpha: 0.15);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _confirmClearAll(BuildContext context, FitnessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to remove all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearNotifications();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: context.appTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Important rank, achievement, and challenge updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
