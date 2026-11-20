/// Domain model representing a user's fitness experience points, levels,
/// and periodic XP progress (weekly and monthly).
class UserXP {
  final String userId;
  final int totalXP;
  final int currentLevel;
  final int weeklyXP;
  final int monthlyXP;
  final DateTime lastUpdated;

  const UserXP({
    required this.userId,
    required this.totalXP,
    required this.currentLevel,
    this.weeklyXP = 0,
    this.monthlyXP = 0,
    required this.lastUpdated,
  });

  /// Calculate level from total XP (500 XP per level)
  static int calculateLevel(int totalXP) {
    if (totalXP <= 0) return 1;
    return (totalXP ~/ 500) + 1;
  }

  /// XP required to complete current level
  int get xpForNextLevel => currentLevel * 500;

  /// Base XP threshold of current level
  int get currentLevelBaseXP => (currentLevel - 1) * 500;

  /// Progress XP within the current level (0 to 499)
  int get xpWithinCurrentLevel => (totalXP - currentLevelBaseXP).clamp(0, 500);

  /// XP remaining until next level up
  int get xpToNextLevel => (xpForNextLevel - totalXP).clamp(0, 500);

  /// Progress fraction (0.0 to 1.0) towards next level
  double get levelProgressFraction =>
      (xpWithinCurrentLevel / 500.0).clamp(0.0, 1.0);

  /// Default starting state for a new user
  factory UserXP.initial({String userId = 'local_user'}) {
    return UserXP(
      userId: userId,
      totalXP: 0,
      currentLevel: 1,
      weeklyXP: 0,
      monthlyXP: 0,
      lastUpdated: DateTime.now(),
    );
  }

  factory UserXP.fromJson(Map<String, dynamic> json) {
    final totalXP = (json['totalXP'] as num? ?? json['total_xp'] as num? ?? 0)
        .toInt();
    final calculatedLevel = UserXP.calculateLevel(totalXP);
    final explicitLevel =
        (json['currentLevel'] as num? ??
                json['current_level'] as num? ??
                calculatedLevel)
            .toInt();

    return UserXP(
      userId:
          json['userId'] as String? ??
          json['user_id'] as String? ??
          'local_user',
      totalXP: totalXP,
      currentLevel: explicitLevel > 0 ? explicitLevel : calculatedLevel,
      weeklyXP: (json['weeklyXP'] as num? ?? json['weekly_xp'] as num? ?? 0)
          .toInt(),
      monthlyXP: (json['monthlyXP'] as num? ?? json['monthly_xp'] as num? ?? 0)
          .toInt(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : (json['last_updated'] != null
                ? DateTime.tryParse(json['last_updated'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'total_xp': totalXP,
    'current_level': currentLevel,
    'weekly_xp': weeklyXP,
    'monthly_xp': monthlyXP,
    'last_updated': lastUpdated.toIso8601String(),
  };

  UserXP copyWith({
    String? userId,
    int? totalXP,
    int? currentLevel,
    int? weeklyXP,
    int? monthlyXP,
    DateTime? lastUpdated,
  }) {
    final effectiveTotalXP = totalXP ?? this.totalXP;
    return UserXP(
      userId: userId ?? this.userId,
      totalXP: effectiveTotalXP,
      currentLevel: currentLevel ?? UserXP.calculateLevel(effectiveTotalXP),
      weeklyXP: weeklyXP ?? this.weeklyXP,
      monthlyXP: monthlyXP ?? this.monthlyXP,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserXP &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          totalXP == other.totalXP &&
          currentLevel == other.currentLevel;

  @override
  int get hashCode =>
      userId.hashCode ^ totalXP.hashCode ^ currentLevel.hashCode;
}
