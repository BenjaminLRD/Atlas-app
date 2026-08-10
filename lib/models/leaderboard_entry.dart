import 'leaderboard_user.dart';

/// Domain model representing a real user leaderboard entry.
class LeaderboardEntry {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int totalXP;
  final String rankTitle;
  final String division;
  final String country;
  final DateTime updatedAt;

  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.totalXP,
    required this.rankTitle,
    required this.division,
    required this.country,
    required this.updatedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] as String? ??
          json['entry_id'] as String? ??
          'entry_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          'usr_local',
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          'Gym Member',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      totalXP: (json['totalXP'] as num?)?.toInt() ??
          (json['total_xp'] as num?)?.toInt() ??
          0,
      rankTitle: json['rankTitle'] as String? ??
          json['rank_title'] as String? ??
          'Bronze I',
      division: json['division'] as String? ?? 'Division III',
      country: json['country'] as String? ?? 'India',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'total_xp': totalXP,
        'rank_title': rankTitle,
        'division': division,
        'country': country,
        'updated_at': updatedAt.toIso8601String(),
      };

  LeaderboardEntry copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? avatarUrl,
    int? totalXP,
    String? rankTitle,
    String? division,
    String? country,
    DateTime? updatedAt,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalXP: totalXP ?? this.totalXP,
      rankTitle: rankTitle ?? this.rankTitle,
      division: division ?? this.division,
      country: country ?? this.country,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Map domain [LeaderboardEntry] to legacy UI component model [LeaderboardUser].
  LeaderboardUser toLeaderboardUser({
    int rankPosition = 1,
    bool isCurrentUser = false,
  }) {
    return LeaderboardUser(
      rankPosition: rankPosition,
      name: displayName,
      rankTitle: rankTitle,
      xp: totalXP,
      imageUrl: avatarUrl,
      isCurrentUser: isCurrentUser,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          totalXP == other.totalXP &&
          country == other.country;

  @override
  int get hashCode =>
      id.hashCode ^ userId.hashCode ^ totalXP.hashCode ^ country.hashCode;
}
