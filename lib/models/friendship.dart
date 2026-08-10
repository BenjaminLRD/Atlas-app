/// Domain model representing a friendship relationship or pending request.
class Friendship {
  final String id;
  final String requesterId;
  final String receiverId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isPending => status.toLowerCase() == 'pending';

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String? ?? '',
      requesterId: json['requesterId'] as String? ??
          json['requester_id'] as String? ??
          '',
      receiverId: json['receiverId'] as String? ??
          json['receiver_id'] as String? ??
          '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requester_id': requesterId,
        'receiver_id': receiverId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  Friendship copyWith({
    String? id,
    String? requesterId,
    String? receiverId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friendship &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requesterId == other.requesterId &&
          receiverId == other.receiverId &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ requesterId.hashCode ^ receiverId.hashCode ^ status.hashCode;
}
