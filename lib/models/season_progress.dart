/// Domain model representing user progress and accumulated XP within a specific season.
class SeasonProgress {
  final String id;
  final String seasonId;
  final String userId;
  final int seasonXP;
  final DateTime updatedAt;

  const SeasonProgress({
    required this.id,
    required this.seasonId,
    required this.userId,
    this.seasonXP = 0,
    required this.updatedAt,
  });

  factory SeasonProgress.fromJson(Map<String, dynamic> json) {
    return SeasonProgress(
      id: json['id'] as String? ?? '',
      seasonId: json['seasonId'] as String? ??
          json['season_id'] as String? ??
          '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          'usr_local',
      seasonXP: json['seasonXP'] as int? ??
          json['season_xp'] as int? ??
          0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'season_id': seasonId,
        'user_id': userId,
        'season_xp': seasonXP,
        'updated_at': updatedAt.toIso8601String(),
      };

  SeasonProgress copyWith({
    String? id,
    String? seasonId,
    String? userId,
    int? seasonXP,
    DateTime? updatedAt,
  }) {
    return SeasonProgress(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      userId: userId ?? this.userId,
      seasonXP: seasonXP ?? this.seasonXP,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonProgress &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          seasonId == other.seasonId &&
          userId == other.userId &&
          seasonXP == other.seasonXP;

  @override
  int get hashCode =>
      id.hashCode ^ seasonId.hashCode ^ userId.hashCode ^ seasonXP.hashCode;
}
