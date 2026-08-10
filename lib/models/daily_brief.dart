import 'brief_item.dart';

/// Aggregated daily fitness brief generated for user guidance.
class DailyBrief {
  final String id;
  final DateTime date;
  final String headline;
  final String summary;
  final String focusArea;
  final List<BriefItem> items;
  final int priority;
  final DateTime createdAt;
  final bool isRead;
  final String? contextSummary;

  const DailyBrief({
    required this.id,
    required this.date,
    required this.headline,
    required this.summary,
    required this.focusArea,
    this.items = const [],
    this.priority = 1,
    required this.createdAt,
    this.isRead = false,
    this.contextSummary,
  });

  DailyBrief copyWith({
    String? id,
    DateTime? date,
    String? headline,
    String? summary,
    String? focusArea,
    List<BriefItem>? items,
    int? priority,
    DateTime? createdAt,
    bool? isRead,
    String? contextSummary,
  }) {
    return DailyBrief(
      id: id ?? this.id,
      date: date ?? this.date,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      focusArea: focusArea ?? this.focusArea,
      items: items ?? this.items,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      contextSummary: contextSummary ?? this.contextSummary,
    );
  }

  factory DailyBrief.fromJson(Map<String, dynamic> json) {
    return DailyBrief(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      headline: json['headline'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      focusArea: json['focusArea'] as String? ?? 'General Fitness',
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => BriefItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      priority: json['priority'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      contextSummary: json['contextSummary'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'headline': headline,
        'summary': summary,
        'focusArea': focusArea,
        'items': items.map((e) => e.toJson()).toList(),
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        if (contextSummary != null) 'contextSummary': contextSummary,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyBrief &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          headline == other.headline &&
          summary == other.summary &&
          focusArea == other.focusArea &&
          priority == other.priority &&
          isRead == other.isRead;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      headline.hashCode ^
      summary.hashCode ^
      focusArea.hashCode ^
      priority.hashCode ^
      isRead.hashCode;
}
