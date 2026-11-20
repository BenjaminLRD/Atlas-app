class LeaderboardUser {
  final int rankPosition;
  final String name;
  final String rankTitle;
  final int xp;
  final String? imageUrl;
  final bool isCurrentUser;

  const LeaderboardUser({
    required this.rankPosition,
    required this.name,
    required this.rankTitle,
    required this.xp,
    this.imageUrl,
    this.isCurrentUser = false,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      rankPosition: (json['rankPosition'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      rankTitle: json['rankTitle'] as String? ?? 'Unranked',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rankPosition': rankPosition,
      'name': name,
      'rankTitle': rankTitle,
      'xp': xp,
      'imageUrl': imageUrl,
      'isCurrentUser': isCurrentUser,
    };
  }

  LeaderboardUser copyWith({
    int? rankPosition,
    String? name,
    String? rankTitle,
    int? xp,
    String? imageUrl,
    bool? isCurrentUser,
  }) {
    return LeaderboardUser(
      rankPosition: rankPosition ?? this.rankPosition,
      name: name ?? this.name,
      rankTitle: rankTitle ?? this.rankTitle,
      xp: xp ?? this.xp,
      imageUrl: imageUrl ?? this.imageUrl,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
