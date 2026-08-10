import 'dart:math';

/// Model representing a user's daily workout streak and consistency metrics
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastWorkoutDate;
  final int streakFreezes;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastWorkoutDate,
    this.streakFreezes = 0,
  });

  /// Factory helper for initial empty streak state
  factory StreakData.initial() {
    return const StreakData(
      currentStreak: 0,
      longestStreak: 0,
      lastWorkoutDate: null,
      streakFreezes: 0,
    );
  }

  /// Create a StreakData instance from JSON map
  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastWorkoutDate: json['lastWorkoutDate'] != null
          ? DateTime.tryParse(json['lastWorkoutDate'] as String)
          : null,
      streakFreezes: (json['streakFreezes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert StreakData instance to JSON map
  Map<String, dynamic> toJson() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
      'streakFreezes': streakFreezes,
    };
  }

  /// Creates a copy of StreakData with updated fields
  StreakData copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastWorkoutDate,
    int? streakFreezes,
  }) {
    return StreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
      streakFreezes: streakFreezes ?? this.streakFreezes,
    );
  }

  /// Helper to convert a DateTime to a date-only DateTime (midnight UTC/local)
  static DateTime _toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Update streak metrics based on a newly completed workout date
  StreakData updateWithWorkout(DateTime workoutDate) {
    final newDateOnly = _toDateOnly(workoutDate);

    if (lastWorkoutDate == null) {
      // First workout ever recorded
      return StreakData(
        currentStreak: 1,
        longestStreak: max(longestStreak, 1),
        lastWorkoutDate: workoutDate,
        streakFreezes: streakFreezes,
      );
    }

    final lastDateOnly = _toDateOnly(lastWorkoutDate!);
    final differenceInDays = newDateOnly.difference(lastDateOnly).inDays;

    if (differenceInDays == 0) {
      // Workout completed on the same day: maintain streak count
      return StreakData(
        currentStreak: currentStreak > 0 ? currentStreak : 1,
        longestStreak: max(longestStreak, currentStreak > 0 ? currentStreak : 1),
        lastWorkoutDate: workoutDate,
        streakFreezes: streakFreezes,
      );
    } else if (differenceInDays == 1) {
      // Workout completed on the consecutive next day: increment streak
      final updatedCurrent = currentStreak + 1;
      return StreakData(
        currentStreak: updatedCurrent,
        longestStreak: max(longestStreak, updatedCurrent),
        lastWorkoutDate: workoutDate,
        streakFreezes: streakFreezes,
      );
    } else {
      // Gap of > 1 day: reset streak to 1
      return StreakData(
        currentStreak: 1,
        longestStreak: max(longestStreak, 1),
        lastWorkoutDate: workoutDate,
        streakFreezes: streakFreezes,
      );
    }
  }

  @override
  String toString() {
    return 'StreakData(current: $currentStreak, longest: $longestStreak, lastDate: $lastWorkoutDate)';
  }
}
