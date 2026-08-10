/// Enum defining types of 1v1 and group friend challenges
enum ChallengeType {
  volumeShowdown, // Total kg lifted
  streakSprint,    // Workout streak days
  xpRace,           // Target XP reached
  workoutCount,     // Total sessions completed
}

/// Enum defining status of a friend challenge
enum ChallengeStatus {
  invited,
  active,
  completed,
  declined,
}

/// Domain model representing a 1v1 or group Friend Challenge
class FriendChallenge {
  final String id;
  final String creatorId;
  final String creatorName;
  final String opponentId;
  final String opponentName;
  final ChallengeType type;
  final ChallengeStatus status;
  final String title;
  final String description;
  final double creatorProgress;
  final double opponentProgress;
  final double targetGoal;
  final int xpReward;
  final String? winnerId;
  final DateTime startDate;
  final DateTime endDate;

  FriendChallenge({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.opponentId,
    required this.opponentName,
    required this.type,
    this.status = ChallengeStatus.invited,
    required this.title,
    required this.description,
    this.creatorProgress = 0.0,
    this.opponentProgress = 0.0,
    required this.targetGoal,
    this.xpReward = 500,
    this.winnerId,
    DateTime? startDate,
    DateTime? endDate,
  })  : startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 7));

  bool get isCompleted => status == ChallengeStatus.completed || winnerId != null;
  bool get isActive => status == ChallengeStatus.active;
  bool get isPending => status == ChallengeStatus.invited;

  double get creatorPercentage => targetGoal > 0 ? (creatorProgress / targetGoal).clamp(0.0, 1.0) : 0.0;
  double get opponentPercentage => targetGoal > 0 ? (opponentProgress / targetGoal).clamp(0.0, 1.0) : 0.0;

  factory FriendChallenge.fromJson(Map<String, dynamic> json) {
    return FriendChallenge(
      id: json['id'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? json['creator_id'] as String? ?? 'usr_local',
      creatorName: json['creatorName'] as String? ?? json['creator_name'] as String? ?? 'You',
      opponentId: json['opponentId'] as String? ?? json['opponent_id'] as String? ?? 'usr_alex',
      opponentName: json['opponentName'] as String? ?? json['opponent_name'] as String? ?? 'Alex Carter',
      type: ChallengeType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'volumeShowdown'),
        orElse: () => ChallengeType.volumeShowdown,
      ),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'invited'),
        orElse: () => ChallengeStatus.invited,
      ),
      title: json['title'] as String? ?? '1v1 Showdown',
      description: json['description'] as String? ?? 'Compete to reach the goal first',
      creatorProgress: (json['creatorProgress'] as num?)?.toDouble() ?? 0.0,
      opponentProgress: (json['opponentProgress'] as num?)?.toDouble() ?? 0.0,
      targetGoal: (json['targetGoal'] as num?)?.toDouble() ?? 10000.0,
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 500,
      winnerId: json['winnerId'] as String? ?? json['winner_id'] as String?,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'opponentId': opponentId,
        'opponentName': opponentName,
        'type': type.name,
        'status': status.name,
        'title': title,
        'description': description,
        'creatorProgress': creatorProgress,
        'opponentProgress': opponentProgress,
        'targetGoal': targetGoal,
        'xpReward': xpReward,
        if (winnerId != null) 'winnerId': winnerId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

  FriendChallenge copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? opponentId,
    String? opponentName,
    ChallengeType? type,
    ChallengeStatus? status,
    String? title,
    String? description,
    double? creatorProgress,
    double? opponentProgress,
    double? targetGoal,
    int? xpReward,
    String? winnerId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return FriendChallenge(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      opponentId: opponentId ?? this.opponentId,
      opponentName: opponentName ?? this.opponentName,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      creatorProgress: creatorProgress ?? this.creatorProgress,
      opponentProgress: opponentProgress ?? this.opponentProgress,
      targetGoal: targetGoal ?? this.targetGoal,
      xpReward: xpReward ?? this.xpReward,
      winnerId: winnerId ?? this.winnerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
