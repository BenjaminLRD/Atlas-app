/// Priority level for proactive coach actions
enum CoachActionPriority { low, medium, high, urgent }

/// Domain model representing a prioritized proactive action recommended by AI Coach.
class CoachAction {
  final String id;
  final String title;
  final String description;
  final String
  category; // 'workout', 'nutrition', 'recovery', 'habit', 'general'
  final CoachActionPriority priority;
  final String? actionRoute;
  final String? actionLabel;
  final bool isCompleted;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const CoachAction({
    required this.id,
    required this.title,
    required this.description,
    this.category = 'general',
    this.priority = CoachActionPriority.medium,
    this.actionRoute,
    this.actionLabel,
    this.isCompleted = false,
    required this.createdAt,
    this.metadata,
  });

  CoachAction copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    CoachActionPriority? priority,
    String? actionRoute,
    String? actionLabel,
    bool? isCompleted,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return CoachAction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      actionRoute: actionRoute ?? this.actionRoute,
      actionLabel: actionLabel ?? this.actionLabel,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  factory CoachAction.fromJson(Map<String, dynamic> json) {
    return CoachAction(
      id:
          json['id'] as String? ??
          'act_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      priority: CoachActionPriority.values.firstWhere(
        (e) => e.name == (json['priority'] as String? ?? 'medium'),
        orElse: () => CoachActionPriority.medium,
      ),
      actionRoute:
          json['actionRoute'] as String? ?? (json['action_route'] as String?),
      actionLabel:
          json['actionLabel'] as String? ?? (json['action_label'] as String?),
      isCompleted:
          json['isCompleted'] as bool? ??
          (json['is_completed'] as bool? ?? false),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'] as String)
                : DateTime.now()),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority.name,
    if (actionRoute != null) 'actionRoute': actionRoute,
    if (actionLabel != null) 'actionLabel': actionLabel,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachAction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ isCompleted.hashCode;
}
