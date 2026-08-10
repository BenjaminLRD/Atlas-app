/// Data model representing an AI-ready fitness insight and recommendation.
class FitnessInsight {
  final String id;
  final String title;
  final String description;
  final String category; // 'performance', 'consistency', 'strength', 'balance', 'motivation'
  final String priority; // 'low', 'medium', 'high'
  final String icon;
  final DateTime createdAt;
  final String suggestedAction;
  final String metricSummary;
  final String actionType;

  const FitnessInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.priority = 'medium',
    this.icon = 'auto_awesome',
    required this.createdAt,
    this.suggestedAction = '',
    this.metricSummary = '',
    this.actionType = 'view_workout',
  });

  factory FitnessInsight.fromJson(Map<String, dynamic> json) {
    return FitnessInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'performance',
      priority: json['priority'] as String? ?? 'medium',
      icon: json['icon'] as String? ?? 'auto_awesome',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      suggestedAction: json['suggestedAction'] as String? ?? '',
      metricSummary: json['metricSummary'] as String? ?? '',
      actionType: json['actionType'] as String? ?? 'view_workout',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
        'suggestedAction': suggestedAction,
        'metricSummary': metricSummary,
        'actionType': actionType,
      };

  FitnessInsight copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? icon,
    DateTime? createdAt,
    String? suggestedAction,
    String? metricSummary,
    String? actionType,
  }) {
    return FitnessInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      metricSummary: metricSummary ?? this.metricSummary,
      actionType: actionType ?? this.actionType,
    );
  }
}
