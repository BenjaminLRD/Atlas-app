/// Domain model representing a system or in-app notification item.
class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'achievement', 'rank_up', 'challenge', 'friend', 'coach', 'reminder'
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;
  final String? icon;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
    this.icon,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          'usr_local',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'reminder',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? false,
      actionRoute: json['actionRoute'] as String? ?? json['action_route'] as String?,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        if (actionRoute != null) 'action_route': actionRoute,
        if (icon != null) 'icon': icon,
      };

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    String? actionRoute,
    String? icon,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      icon: icon ?? this.icon,
    );
  }

  factory NotificationItem.friendRequest({required String fromUserName}) {
    return NotificationItem(
      id: 'notif_fr_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'usr_local',
      title: 'New Friend Request',
      message: '$fromUserName wants to connect on Aizawl Gym',
      type: 'friend',
      createdAt: DateTime.now(),
      icon: 'person_add',
    );
  }

  factory NotificationItem.friendAccepted({required String fromUserName}) {
    return NotificationItem(
      id: 'notif_fa_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'usr_local',
      title: 'Friend Request Accepted',
      message: '$fromUserName accepted your friend request',
      type: 'friend',
      createdAt: DateTime.now(),
      icon: 'people',
    );
  }

  factory NotificationItem.challengeReceived({required String fromUserName, required String challengeTitle}) {
    return NotificationItem(
      id: 'notif_ch_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'usr_local',
      title: '1v1 Challenge Received!',
      message: '$fromUserName challenged you to "$challengeTitle"',
      type: 'challenge',
      createdAt: DateTime.now(),
      icon: 'emoji_events',
    );
  }

  factory NotificationItem.referralConverted({required String friendName, required int xpReward}) {
    return NotificationItem(
      id: 'notif_ref_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'usr_local',
      title: 'Referral Bonus Earned!',
      message: '$friendName joined using your referral code. +$xpReward XP earned!',
      type: 'referral',
      createdAt: DateTime.now(),
      icon: 'card_giftcard',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          type == other.type &&
          isRead == other.isRead;

  @override
  int get hashCode =>
      id.hashCode ^ userId.hashCode ^ title.hashCode ^ type.hashCode ^ isRead.hashCode;
}
