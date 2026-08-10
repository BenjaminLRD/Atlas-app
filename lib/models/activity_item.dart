/// Domain model representing a user fitness activity feed item.
class ActivityItem {
  final String id;
  final String userId;
  final String type; // 'workout', 'achievement', 'rank_up', 'challenge'
  final String title;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final Map<String, int> reactions;
  final int commentsCount;
  final String? userReaction;

  const ActivityItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.metadata,
    this.reactions = const {'like': 0, 'fire': 0, 'respect': 0, 'legendary': 0},
    this.commentsCount = 0,
    this.userReaction,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as Map<String, dynamic>?;
    final Map<String, int> parsedReactions = rawReactions != null
        ? rawReactions.map((k, v) => MapEntry(k, (v as num).toInt()))
        : const {'like': 3, 'fire': 5, 'respect': 2, 'legendary': 1};

    return ActivityItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          'usr_local',
      type: json['type'] as String? ?? 'workout',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
      metadata: json['metadata'] as Map<String, dynamic>?,
      reactions: parsedReactions,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? (json['comments_count'] as num?)?.toInt() ?? 2,
      userReaction: json['userReaction'] as String? ?? json['user_reaction'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
        'reactions': reactions,
        'comments_count': commentsCount,
        if (userReaction != null) 'user_reaction': userReaction,
      };

  ActivityItem copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? description,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    Map<String, int>? reactions,
    int? commentsCount,
    String? userReaction,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      reactions: reactions ?? this.reactions,
      commentsCount: commentsCount ?? this.commentsCount,
      userReaction: userReaction ?? this.userReaction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          type == other.type &&
          title == other.title;

  @override
  int get hashCode =>
      id.hashCode ^ userId.hashCode ^ type.hashCode ^ title.hashCode;
}
