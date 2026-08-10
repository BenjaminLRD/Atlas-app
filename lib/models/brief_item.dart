/// Single actionable item within a daily briefing.
class BriefItem {
  final String title;
  final String description;
  final String category;
  final String icon;
  final String? actionTitle;
  final String? actionRoute;

  const BriefItem({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.actionTitle,
    this.actionRoute,
  });

  BriefItem copyWith({
    String? title,
    String? description,
    String? category,
    String? icon,
    String? actionTitle,
    String? actionRoute,
  }) {
    return BriefItem(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      actionTitle: actionTitle ?? this.actionTitle,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }

  factory BriefItem.fromJson(Map<String, dynamic> json) {
    return BriefItem(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      icon: json['icon'] as String? ?? 'auto_awesome',
      actionTitle: json['actionTitle'] as String?,
      actionRoute: json['actionRoute'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'icon': icon,
        if (actionTitle != null) 'actionTitle': actionTitle,
        if (actionRoute != null) 'actionRoute': actionRoute,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BriefItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          icon == other.icon &&
          actionTitle == other.actionTitle &&
          actionRoute == other.actionRoute;

  @override
  int get hashCode =>
      title.hashCode ^
      description.hashCode ^
      category.hashCode ^
      icon.hashCode ^
      actionTitle.hashCode ^
      actionRoute.hashCode;
}
