class UserProgress {
  final int totalXP;
  final int completedWorkouts;
  final bool rankedUnlocked;
  final String currentRank;
  final String currentDivision;
  final int workoutStreak;
  final int longestStreak;
  final DateTime? lastWorkoutDate;
  final int totalWorkoutMinutes;
  final double totalVolumeLifted;
  final List<String> achievements;
  final int nutritionStreak;

  const UserProgress({
    required this.totalXP,
    required this.completedWorkouts,
    required this.rankedUnlocked,
    required this.currentRank,
    required this.currentDivision,
    required this.workoutStreak,
    required this.longestStreak,
    this.lastWorkoutDate,
    required this.totalWorkoutMinutes,
    required this.totalVolumeLifted,
    required this.achievements,
    this.nutritionStreak = 0,
  });

  /// Alias for completedWorkouts for backward compatibility
  int get totalWorkouts => completedWorkouts;

  /// Returns full rank title e.g. "Bronze IV" or "Unranked"
  String get fullRank {
    if (!rankedUnlocked || currentRank == 'Unranked') return 'Unranked';
    if (currentDivision.isEmpty || currentDivision == 'Unranked') return currentRank;
    return '$currentRank $currentDivision';
  }

  /// Default starting progress state before unlocking Ranked mode (< 5 workouts)
  factory UserProgress.initial() {
    return const UserProgress(
      totalXP: 0,
      completedWorkouts: 0,
      rankedUnlocked: false,
      currentRank: 'Unranked',
      currentDivision: 'Unranked',
      workoutStreak: 0,
      longestStreak: 0,
      lastWorkoutDate: null,
      totalWorkoutMinutes: 0,
      totalVolumeLifted: 0.0,
      achievements: [],
      nutritionStreak: 0,
    );
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final rawAchievements = json['achievements'] as List?;
    final List<String> achievementsList = rawAchievements != null
        ? rawAchievements.map((e) => e.toString()).toList()
        : [];

    final int workouts = (json['completedWorkouts'] as num?)?.toInt() ??
        (json['totalWorkouts'] as num?)?.toInt() ??
        0;
    final bool isUnlocked = (json['rankedUnlocked'] as bool?) ?? (workouts >= 5);

    return UserProgress(
      totalXP: (json['totalXP'] as num?)?.toInt() ?? 0,
      completedWorkouts: workouts,
      rankedUnlocked: isUnlocked,
      currentRank: json['currentRank'] as String? ?? (isUnlocked ? 'Bronze' : 'Unranked'),
      currentDivision: json['currentDivision'] as String? ?? (isUnlocked ? 'IV' : 'Unranked'),
      workoutStreak: (json['workoutStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastWorkoutDate: json['lastWorkoutDate'] != null
          ? DateTime.tryParse(json['lastWorkoutDate'] as String)
          : null,
      totalWorkoutMinutes: (json['totalWorkoutMinutes'] as num?)?.toInt() ?? 0,
      totalVolumeLifted: (json['totalVolumeLifted'] as num?)?.toDouble() ?? 0.0,
      achievements: achievementsList,
      nutritionStreak: (json['nutritionStreak'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalXP': totalXP,
      'completedWorkouts': completedWorkouts,
      'totalWorkouts': completedWorkouts,
      'rankedUnlocked': rankedUnlocked,
      'currentRank': currentRank,
      'currentDivision': currentDivision,
      'workoutStreak': workoutStreak,
      'longestStreak': longestStreak,
      'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
      'totalWorkoutMinutes': totalWorkoutMinutes,
      'totalVolumeLifted': totalVolumeLifted,
      'achievements': achievements,
      'nutritionStreak': nutritionStreak,
    };
  }

  UserProgress copyWith({
    int? totalXP,
    int? completedWorkouts,
    bool? rankedUnlocked,
    String? currentRank,
    String? currentDivision,
    int? workoutStreak,
    int? longestStreak,
    DateTime? lastWorkoutDate,
    int? totalWorkoutMinutes,
    double? totalVolumeLifted,
    List<String>? achievements,
    int? nutritionStreak,
  }) {
    return UserProgress(
      totalXP: totalXP ?? this.totalXP,
      completedWorkouts: completedWorkouts ?? this.completedWorkouts,
      rankedUnlocked: rankedUnlocked ?? this.rankedUnlocked,
      currentRank: currentRank ?? this.currentRank,
      currentDivision: currentDivision ?? this.currentDivision,
      workoutStreak: workoutStreak ?? this.workoutStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
      totalWorkoutMinutes: totalWorkoutMinutes ?? this.totalWorkoutMinutes,
      totalVolumeLifted: totalVolumeLifted ?? this.totalVolumeLifted,
      achievements: achievements ?? List.from(this.achievements),
      nutritionStreak: nutritionStreak ?? this.nutritionStreak,
    );
  }
}
