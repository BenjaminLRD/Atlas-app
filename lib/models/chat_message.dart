class ChatMessage {
  String sender;
  String text;
  List<String>? tags;
  bool? routineCard;

  ChatMessage({
    required this.sender,
    required this.text,
    this.tags,
    this.routineCard,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String? ?? 'user',
      text: json['text'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      routineCard: json['routineCard'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sender': sender,
      'text': text,
    };
    if (tags != null) map['tags'] = tags;
    if (routineCard != null) map['routineCard'] = routineCard;
    return map;
  }

  /// Map indexing operator for backwards compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'sender':
        return sender;
      case 'text':
        return text;
      case 'tags':
        return tags;
      case 'routineCard':
        return routineCard;
      default:
        return null;
    }
  }

  /// Map assignment operator for backwards compatibility
  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'sender':
        sender = value?.toString() ?? sender;
        break;
      case 'text':
        text = value?.toString() ?? text;
        break;
      case 'tags':
        if (value is List) {
          tags = value.map((e) => e.toString()).toList();
        } else if (value == null) {
          tags = null;
        }
        break;
      case 'routineCard':
        routineCard = value as bool?;
        break;
    }
  }

  ChatMessage copyWith({
    String? sender,
    String? text,
    List<String>? tags,
    bool? routineCard,
  }) {
    return ChatMessage(
      sender: sender ?? this.sender,
      text: text ?? this.text,
      tags: tags ?? (this.tags != null ? List.from(this.tags!) : null),
      routineCard: routineCard ?? this.routineCard,
    );
  }
}
