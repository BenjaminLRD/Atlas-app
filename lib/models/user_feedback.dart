/// Structured feedback item submitted by beta testers and athletes.
class UserFeedback {
  final String id;
  final String userId;
  final String feedback;
  final String category; // 'bug', 'feature_request', 'ui_issue', 'ai_issue'
  final String priority; // 'low', 'medium', 'high', 'critical'
  final Map<String, dynamic> deviceInfo;
  final DateTime timestamp;

  const UserFeedback({
    required this.id,
    required this.userId,
    required this.feedback,
    required this.category,
    this.priority = 'medium',
    this.deviceInfo = const {},
    required this.timestamp,
  });

  factory UserFeedback.fromJson(Map<String, dynamic> json) {
    return UserFeedback(
      id:
          json['id']?.toString() ??
          'fb_${DateTime.now().millisecondsSinceEpoch}',
      userId:
          json['user_id']?.toString() ??
          json['userId']?.toString() ??
          'usr_local',
      feedback: json['feedback']?.toString() ?? '',
      category: json['category']?.toString() ?? 'bug',
      priority: json['priority']?.toString() ?? 'medium',
      deviceInfo: json['device_info'] != null
          ? Map<String, dynamic>.from(json['device_info'] as Map)
          : (json['deviceInfo'] != null
                ? Map<String, dynamic>.from(json['deviceInfo'] as Map)
                : const {}),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'feedback': feedback,
    'category': category,
    'priority': priority,
    'device_info': deviceInfo,
    'timestamp': timestamp.toIso8601String(),
  };

  UserFeedback copyWith({
    String? id,
    String? userId,
    String? feedback,
    String? category,
    String? priority,
    Map<String, dynamic>? deviceInfo,
    DateTime? timestamp,
  }) {
    return UserFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      feedback: feedback ?? this.feedback,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
