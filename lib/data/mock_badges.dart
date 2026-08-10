import '../models/badge.dart';
import '../providers/fitness_provider.dart';
import '../services/achievement_service.dart';

/// Badge Data Service providing achievement badge datasets and APIs.
/// Connects dynamically to FitnessProvider userProgress achievements.
class BadgeService {
  /// Retrieve recently earned badges for the current user
  List<AchievementBadge> getRecentBadges() {
    final unlockedIds = FitnessProvider.instance.userProgress.achievements;
    final all = AchievementService.allAchievements;
    final now = DateTime.now();

    if (unlockedIds.isEmpty) {
      // Default preview set for initial exploration before milestones
      return [
        all.firstWhere((b) => b.id == 'streak_7').copyWith(
              earnedDate: now.subtract(const Duration(days: 2)),
              isUnlocked: true,
            ),
        all.firstWhere((b) => b.id == 'workouts_10').copyWith(
              earnedDate: now.subtract(const Duration(days: 5)),
              isUnlocked: true,
            ),
        all.firstWhere((b) => b.id == 'personal_record').copyWith(
              earnedDate: now.subtract(const Duration(days: 8)),
              isUnlocked: true,
            ),
      ];
    }

    return all.where((b) => unlockedIds.contains(b.id)).map((b) {
      return b.copyWith(
        isUnlocked: true,
        earnedDate: now.subtract(const Duration(days: 1)),
      );
    }).toList();
  }

  /// Retrieve complete achievement collection (unlocked & locked)
  List<AchievementBadge> getAllBadges() {
    final unlockedIds = FitnessProvider.instance.userProgress.achievements;
    final all = AchievementService.allAchievements;
    final now = DateTime.now();

    return all.map((b) {
      final bool isUnlocked = unlockedIds.contains(b.id);
      return b.copyWith(
        isUnlocked: isUnlocked,
        earnedDate: isUnlocked ? now.subtract(const Duration(days: 1)) : null,
      );
    }).toList();
  }
}
