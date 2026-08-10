enum RecommendationCategory {
  training,
  nutrition,
  recovery,
  gamification,
  mindset,
}

enum RecommendationPriority {
  high,
  medium,
  low,
}

/// Data model representing a personalized, explainable AI recommendation.
class Recommendation {
  final String id;
  final String title;
  final String description;
  final RecommendationCategory category;
  final RecommendationPriority priority;
  final String actionTitle;
  final String? actionRoute;
  final String reasoning;
  final String? metricTrigger;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isDismissed;

  const Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.priority = RecommendationPriority.medium,
    required this.actionTitle,
    this.actionRoute,
    required this.reasoning,
    this.metricTrigger,
    required this.createdAt,
    this.expiresAt,
    this.isDismissed = false,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: RecommendationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => RecommendationCategory.training,
      ),
      priority: RecommendationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => RecommendationPriority.medium,
      ),
      actionTitle: json['actionTitle'] as String? ?? '',
      actionRoute: json['actionRoute'] as String?,
      reasoning: json['reasoning'] as String? ?? '',
      metricTrigger: json['metricTrigger'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'priority': priority.name,
        'actionTitle': actionTitle,
        if (actionRoute != null) 'actionRoute': actionRoute,
        'reasoning': reasoning,
        if (metricTrigger != null) 'metricTrigger': metricTrigger,
        'createdAt': createdAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'isDismissed': isDismissed,
      };

  Recommendation copyWith({
    String? id,
    String? title,
    String? description,
    RecommendationCategory? category,
    RecommendationPriority? priority,
    String? actionTitle,
    String? actionRoute,
    String? reasoning,
    String? metricTrigger,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isDismissed,
  }) {
    return Recommendation(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      actionTitle: actionTitle ?? this.actionTitle,
      actionRoute: actionRoute ?? this.actionRoute,
      reasoning: reasoning ?? this.reasoning,
      metricTrigger: metricTrigger ?? this.metricTrigger,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}
