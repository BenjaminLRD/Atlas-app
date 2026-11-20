import 'dart:async';
import '../../data/gamification_service.dart';
import '../../data/local_storage.dart';
import '../../models/user_xp.dart';

/// Standardized XP reward values for fitness activities.
class FitnessXP {
  static const int workoutCompleted = 100;
  static const int personalRecord = 250;
  static const int workoutStreakPerDay = 50;
  static const int mealLogging = 20;
  static const int communityContribution = 30;
  static const int challengeCompletion = 500;
}

/// Event dispatched when XP is awarded to a user.
class XPAwardEvent {
  final String userId;
  final int amount;
  final String source;
  final UserXP previousXP;
  final UserXP currentXP;
  final bool didLevelUp;
  final int newLevel;
  final DateTime timestamp;

  const XPAwardEvent({
    required this.userId,
    required this.amount,
    required this.source,
    required this.previousXP,
    required this.currentXP,
    required this.didLevelUp,
    required this.newLevel,
    required this.timestamp,
  });
}

/// Central Gamification 2.0 service managing user fitness XP, level progressions,
/// weekly and monthly aggregations, and synchronization with ranks.
class XPService {
  static XPService? _instance;
  static XPService get instance => _instance ??= XPService();

  final GamificationService _gamificationService;
  final StreamController<XPAwardEvent> _xpEventController =
      StreamController<XPAwardEvent>.broadcast();

  XPService({GamificationService? gamificationService})
    : _gamificationService = gamificationService ?? GamificationService();

  /// Stream of all XP reward events for reactive UI and celebrations
  Stream<XPAwardEvent> get xpEvents => _xpEventController.stream;

  /// Retrieve active [UserXP] profile
  UserXP getUserXP({String? userId}) {
    final effectiveUserId = userId ?? 'local_user';
    return LocalStorage.getUserXP(userId: effectiveUserId);
  }

  /// Award XP for completing a workout session (+100 XP base, +250 per PR, +50 per streak day)
  ///
  /// Not used by the workout completion flow: finishing a workout is recorded
  /// by `FitnessProvider.saveWorkoutCompletion`, whose XP comes from
  /// `WorkoutXpCalculator`. This is the separate level/weekly-XP track and has
  /// its own rules; do not call it for a finished workout as well.
  Future<UserXP> awardWorkoutXP({
    required String userId,
    int streakDays = 0,
    int prCount = 0,
  }) async {
    final baseXP = FitnessXP.workoutCompleted;
    final prXP = prCount * FitnessXP.personalRecord;
    final streakXP = streakDays * FitnessXP.workoutStreakPerDay;
    final totalGain = baseXP + prXP + streakXP;

    return awardXP(
      userId: userId,
      amount: totalGain,
      source: 'workout_completed',
    );
  }

  /// Award XP for achieving Personal Records (+250 XP per PR)
  Future<UserXP> awardPersonalRecordXP({
    required String userId,
    int count = 1,
  }) async {
    final totalGain = count * FitnessXP.personalRecord;
    return awardXP(
      userId: userId,
      amount: totalGain,
      source: 'personal_record',
    );
  }

  /// Award XP for daily workout streak (+50 XP / day)
  Future<UserXP> awardStreakXP({
    required String userId,
    required int streakDays,
  }) async {
    final totalGain = streakDays * FitnessXP.workoutStreakPerDay;
    return awardXP(userId: userId, amount: totalGain, source: 'workout_streak');
  }

  /// Award XP for logging daily nutrition / meals (+20 XP)
  Future<UserXP> awardMealLogXP({required String userId}) async {
    return awardXP(
      userId: userId,
      amount: FitnessXP.mealLogging,
      source: 'meal_logged',
    );
  }

  /// Award XP for contributing to the community (+30 XP)
  Future<UserXP> awardCommunityXP({
    required String userId,
    String activityType = 'post',
  }) async {
    return awardXP(
      userId: userId,
      amount: FitnessXP.communityContribution,
      source: 'community_$activityType',
    );
  }

  /// Award XP for completing a weekly or monthly challenge (+500 XP)
  Future<UserXP> awardChallengeXP({
    required String userId,
    String? challengeId,
  }) async {
    return awardXP(
      userId: userId,
      amount: FitnessXP.challengeCompletion,
      source: 'challenge_completed',
    );
  }

  /// Core XP modification engine: handles weekly/monthly reset boundaries,
  /// level progression calculations, persistence, rank synchronization, and event broadcasting.
  Future<UserXP> awardXP({
    required String userId,
    required int amount,
    required String source,
  }) async {
    if (amount <= 0) {
      return getUserXP(userId: userId);
    }

    final current = getUserXP(userId: userId);
    final now = DateTime.now();

    // Check weekly / monthly resets
    final isSameWeek = _isSameIsoWeek(current.lastUpdated, now);
    final isSameMonth =
        current.lastUpdated.year == now.year &&
        current.lastUpdated.month == now.month;

    final newWeeklyXP = isSameWeek ? (current.weeklyXP + amount) : amount;
    final newMonthlyXP = isSameMonth ? (current.monthlyXP + amount) : amount;
    final newTotalXP = current.totalXP + amount;
    final newLevel = UserXP.calculateLevel(newTotalXP);
    final didLevelUp = newLevel > current.currentLevel;

    final updated = current.copyWith(
      totalXP: newTotalXP,
      currentLevel: newLevel,
      weeklyXP: newWeeklyXP,
      monthlyXP: newMonthlyXP,
      lastUpdated: now,
    );

    // Save to LocalStorage
    await LocalStorage.saveUserXP(updated);

    // Synchronize XP with GamificationService & UserProgress
    final userProgress = _gamificationService.getProgress();
    final updatedProgress = _gamificationService.addXP(amount, userProgress);
    await _gamificationService.saveProgress(updatedProgress);

    // Dispatch event
    final event = XPAwardEvent(
      userId: userId,
      amount: amount,
      source: source,
      previousXP: current,
      currentXP: updated,
      didLevelUp: didLevelUp,
      newLevel: newLevel,
      timestamp: now,
    );
    _xpEventController.add(event);

    return updated;
  }

  /// Check if two dates fall in the same ISO calendar week (Monday to Sunday)
  static bool _isSameIsoWeek(DateTime a, DateTime b) {
    final mondayA = a.subtract(Duration(days: a.weekday - 1));
    final mondayB = b.subtract(Duration(days: b.weekday - 1));
    return mondayA.year == mondayB.year &&
        mondayA.month == mondayB.month &&
        mondayA.day == mondayB.day;
  }

  void dispose() {
    _xpEventController.close();
  }
}
