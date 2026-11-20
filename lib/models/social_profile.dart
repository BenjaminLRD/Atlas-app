/// Gamified athlete ranks based on lifetime earned XP.
enum SocialAthleteRank {
  beginner('Beginner', '🌱', 0),
  risingAthlete('Rising Athlete', '⚡', 1000),
  ironWarrior('Iron Warrior', '⚔️', 5000),
  elite('Elite', '👑', 15000),
  legend('Legend', '🔥', 30000);

  final String title;
  final String icon;
  final int minXp;

  const SocialAthleteRank(this.title, this.icon, this.minXp);

  static SocialAthleteRank fromXp(int xp) {
    if (xp >= 30000) return SocialAthleteRank.legend;
    if (xp >= 15000) return SocialAthleteRank.elite;
    if (xp >= 5000) return SocialAthleteRank.ironWarrior;
    if (xp >= 1000) return SocialAthleteRank.risingAthlete;
    return SocialAthleteRank.beginner;
  }
}

/// Comprehensive Social Profile model representing an athlete's public fitness presence,
/// competitive statistics, tier ranks, and community engagement.
class SocialProfile {
  final String userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String fitnessLevel;
  final int totalXp;
  final SocialAthleteRank rank;
  final int followersCount;
  final int followingCount;
  final int workoutsCompleted;
  final double totalVolumeKg;
  final int currentStreakDays;
  final List<String> achievements;

  const SocialProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.fitnessLevel = 'Intermediate',
    this.totalXp = 0,
    this.rank = SocialAthleteRank.beginner,
    this.followersCount = 0,
    this.followingCount = 0,
    this.workoutsCompleted = 0,
    this.totalVolumeKg = 0.0,
    this.currentStreakDays = 0,
    this.achievements = const [],
  });

  /// Formatted title with icon e.g. "Iron Warrior ⚔️"
  String get rankDisplay => '${rank.title} ${rank.icon}';

  SocialProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? fitnessLevel,
    int? totalXp,
    SocialAthleteRank? rank,
    int? followersCount,
    int? followingCount,
    int? workoutsCompleted,
    double? totalVolumeKg,
    int? currentStreakDays,
    List<String>? achievements,
  }) {
    final newXp = totalXp ?? this.totalXp;
    return SocialProfile(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      totalXp: newXp,
      rank: rank ?? SocialAthleteRank.fromXp(newXp),
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      workoutsCompleted: workoutsCompleted ?? this.workoutsCompleted,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      achievements: achievements ?? this.achievements,
    );
  }

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    final xp = (json['total_xp'] as num?)?.toInt() ?? 0;
    return SocialProfile(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      username: json['username'] as String? ?? 'athlete',
      displayName: json['display_name'] as String? ?? json['displayName'] as String? ?? 'Athlete',
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String? ?? '',
      fitnessLevel: json['fitness_level'] as String? ?? json['fitnessLevel'] as String? ?? 'Intermediate',
      totalXp: xp,
      rank: SocialAthleteRank.fromXp(xp),
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      workoutsCompleted: (json['workouts_completed'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0.0,
      currentStreakDays: (json['current_streak_days'] as num?)?.toInt() ?? 0,
      achievements: (json['achievements'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'fitness_level': fitnessLevel,
      'total_xp': totalXp,
      'rank_title': rank.title,
      'followers_count': followersCount,
      'following_count': followingCount,
      'workouts_completed': workoutsCompleted,
      'total_volume_kg': totalVolumeKg,
      'current_streak_days': currentStreakDays,
      'achievements': achievements,
    };
  }
}
