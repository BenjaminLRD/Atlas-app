class NotificationModel {
  String id;
  String title;
  String body;
  String timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  /// Map indexing operator for backwards compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'title':
        return title;
      case 'body':
        return body;
      case 'timestamp':
        return timestamp;
      case 'isRead':
        return isRead;
      default:
        return null;
    }
  }

  /// Map assignment operator for backwards compatibility
  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'id':
        id = value?.toString() ?? id;
        break;
      case 'title':
        title = value?.toString() ?? title;
        break;
      case 'body':
        body = value?.toString() ?? body;
        break;
      case 'timestamp':
        timestamp = value?.toString() ?? timestamp;
        break;
      case 'isRead':
        if (value is bool) isRead = value;
        break;
    }
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
