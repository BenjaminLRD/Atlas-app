import 'package:flutter/foundation.dart';

/// Defines the role of a message sender in the AI Coach conversation architecture.
enum CoachRole {
  system,
  user,
  assistant;

  String toJson() => name;

  static CoachRole fromJson(String json) {
    return CoachRole.values.firstWhere(
      (e) => e.name == json,
      orElse: () => CoachRole.assistant,
    );
  }
}

/// Represents a single message exchange in the AI Coach chat architecture.
@immutable
class CoachMessage {
  final String id;
  final CoachRole role;
  final String content;
  final DateTime timestamp;
  final String? category;
  final Map<String, dynamic>? contextSnapshot;

  const CoachMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.category,
    this.contextSnapshot,
  });

  CoachMessage copyWith({
    String? id,
    CoachRole? role,
    String? content,
    DateTime? timestamp,
    String? category,
    Map<String, dynamic>? contextSnapshot,
  }) {
    return CoachMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      contextSnapshot: contextSnapshot ?? this.contextSnapshot,
    );
  }

  factory CoachMessage.fromJson(Map<String, dynamic> json) {
    return CoachMessage(
      id: json['id'] as String? ?? '',
      role: CoachRole.fromJson(json['role'] as String? ?? 'assistant'),
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      category: json['category'] as String?,
      contextSnapshot: json['contextSnapshot'] != null
          ? Map<String, dynamic>.from(json['contextSnapshot'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.toJson(),
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (category != null) 'category': category,
        if (contextSnapshot != null) 'contextSnapshot': contextSnapshot,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          content == other.content &&
          timestamp == other.timestamp &&
          category == other.category;

  @override
  int get hashCode =>
      id.hashCode ^
      role.hashCode ^
      content.hashCode ^
      timestamp.hashCode ^
      category.hashCode;
}
