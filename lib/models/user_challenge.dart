/// Domain model tracking a user's individual progress on a specific challenge.
class UserChallenge {
  final String id;
  final String userId;
  final String challengeId;
  final double progress;
  final bool completed;
  final DateTime? completedAt;
  final bool rewardClaimed;

  const UserChallenge({
    required this.id,
    required this.userId,
    required this.challengeId,
    this.progress = 0.0,
    this.completed = false,
    this.completedAt,
    this.rewardClaimed = false,
  });

  factory UserChallenge.fromJson(Map<String, dynamic> json) {
    return UserChallenge(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          'usr_local',
      challengeId: json['challengeId'] as String? ??
          json['challenge_id'] as String? ??
          '',
      progress: (json['progress'] as num?)?.toDouble() ??
          (json['current_progress'] as num?)?.toDouble() ??
          0.0,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : (json['completed_at'] != null
              ? DateTime.parse(json['completed_at'] as String)
              : null),
      rewardClaimed: json['rewardClaimed'] as bool? ??
          json['reward_claimed'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'challenge_id': challengeId,
        'current_progress': progress,
        'completed': completed,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        'reward_claimed': rewardClaimed,
      };

  UserChallenge copyWith({
    String? id,
    String? userId,
    String? challengeId,
    double? progress,
    bool? completed,
    DateTime? completedAt,
    bool? rewardClaimed,
  }) {
    return UserChallenge(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challengeId: challengeId ?? this.challengeId,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserChallenge &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          challengeId == other.challengeId &&
          progress == other.progress &&
          completed == other.completed &&
          rewardClaimed == other.rewardClaimed;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      challengeId.hashCode ^
      progress.hashCode ^
      completed.hashCode ^
      rewardClaimed.hashCode;
}
