import 'dart:math';

/// Model representing a user's nutrition gamification metrics, streak tracking,
/// and milestone achievements.
class NutritionProgress {
  final int currentNutritionStreak;
  final int longestNutritionStreak;
  final int totalMealsCompleted;
  final int totalProteinGoalsAchieved;
  final DateTime? lastNutritionDate;

  const NutritionProgress({
    required this.currentNutritionStreak,
    required this.longestNutritionStreak,
    required this.totalMealsCompleted,
    required this.totalProteinGoalsAchieved,
    this.lastNutritionDate,
  });

  /// Factory helper for initial empty nutrition progress state
  factory NutritionProgress.initial() {
    return const NutritionProgress(
      currentNutritionStreak: 0,
      longestNutritionStreak: 0,
      totalMealsCompleted: 0,
      totalProteinGoalsAchieved: 0,
      lastNutritionDate: null,
    );
  }

  /// Create a NutritionProgress instance from JSON map
  factory NutritionProgress.fromJson(Map<String, dynamic> json) {
    return NutritionProgress(
      currentNutritionStreak:
          (json['currentNutritionStreak'] as num?)?.toInt() ?? 0,
      longestNutritionStreak:
          (json['longestNutritionStreak'] as num?)?.toInt() ?? 0,
      totalMealsCompleted:
          (json['totalMealsCompleted'] as num?)?.toInt() ?? 0,
      totalProteinGoalsAchieved:
          (json['totalProteinGoalsAchieved'] as num?)?.toInt() ?? 0,
      lastNutritionDate: json['lastNutritionDate'] != null
          ? DateTime.tryParse(json['lastNutritionDate'] as String)
          : null,
    );
  }

  /// Convert NutritionProgress instance to JSON map
  Map<String, dynamic> toJson() {
    return {
      'currentNutritionStreak': currentNutritionStreak,
      'longestNutritionStreak': longestNutritionStreak,
      'totalMealsCompleted': totalMealsCompleted,
      'totalProteinGoalsAchieved': totalProteinGoalsAchieved,
      'lastNutritionDate': lastNutritionDate?.toIso8601String(),
    };
  }

  /// Creates a copy of NutritionProgress with updated fields
  NutritionProgress copyWith({
    int? currentNutritionStreak,
    int? longestNutritionStreak,
    int? totalMealsCompleted,
    int? totalProteinGoalsAchieved,
    DateTime? lastNutritionDate,
  }) {
    return NutritionProgress(
      currentNutritionStreak:
          currentNutritionStreak ?? this.currentNutritionStreak,
      longestNutritionStreak:
          longestNutritionStreak ?? this.longestNutritionStreak,
      totalMealsCompleted:
          totalMealsCompleted ?? this.totalMealsCompleted,
      totalProteinGoalsAchieved:
          totalProteinGoalsAchieved ?? this.totalProteinGoalsAchieved,
      lastNutritionDate: lastNutritionDate ?? this.lastNutritionDate,
    );
  }

  /// Date-only helper
  static DateTime _toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Update streak metrics based on a qualifying nutrition event date
  NutritionProgress updateStreak(DateTime eventDate) {
    final eventDateOnly = _toDateOnly(eventDate);

    if (lastNutritionDate == null) {
      return copyWith(
        currentNutritionStreak: 1,
        longestNutritionStreak: max(longestNutritionStreak, 1),
        lastNutritionDate: eventDate,
      );
    }

    final lastDateOnly = _toDateOnly(lastNutritionDate!);
    final diffDays = eventDateOnly.difference(lastDateOnly).inDays;

    if (diffDays == 0) {
      // Same day: maintain current streak count
      final updatedStreak =
          currentNutritionStreak > 0 ? currentNutritionStreak : 1;
      return copyWith(
        currentNutritionStreak: updatedStreak,
        longestNutritionStreak: max(longestNutritionStreak, updatedStreak),
        lastNutritionDate: eventDate,
      );
    } else if (diffDays == 1) {
      // Consecutive day: increment streak
      final updatedStreak = currentNutritionStreak + 1;
      return copyWith(
        currentNutritionStreak: updatedStreak,
        longestNutritionStreak: max(longestNutritionStreak, updatedStreak),
        lastNutritionDate: eventDate,
      );
    } else {
      // Gap > 1 day: reset streak to 1
      return copyWith(
        currentNutritionStreak: 1,
        longestNutritionStreak: max(longestNutritionStreak, 1),
        lastNutritionDate: eventDate,
      );
    }
  }

  @override
  String toString() {
    return 'NutritionProgress(currentStreak: $currentNutritionStreak, longestStreak: $longestNutritionStreak, meals: $totalMealsCompleted, proteinGoals: $totalProteinGoalsAchieved, lastDate: $lastNutritionDate)';
  }
}
