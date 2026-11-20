import '../data/local_storage.dart';
import '../models/challenge.dart';
import '../models/user_challenge.dart';
import '../models/weekly_challenge.dart';
import '../models/workout_history.dart';
import 'supabase/supabase_client.dart';

/// Central service managing weekly challenges, automatic progress calculation
/// across workouts & nutrition, reward claiming, and Supabase / local persistence.
class ChallengeService {
  static ChallengeService? _instance;
  final SupabaseClientManager _clientManager;

  List<WeeklyChallenge>? _cachedLegacyChallenges;
  List<Challenge>? _cachedActiveChallenges;
  List<UserChallenge>? _cachedUserChallenges;

  ChallengeService({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Reset singleton instance (useful for unit testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static ChallengeService get instance {
    _instance ??= ChallengeService();
    return _instance!;
  }

  // --- Default Active Challenges Dataset ---
  List<Challenge> _getDefaultActiveChallenges() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );

    return [
      Challenge(
        id: 'ch_training_5',
        title: 'Weekly Iron Warrior',
        description: 'Complete 5 workout sessions this week',
        category: 'training',
        targetValue: 5.0,
        rewardXP: 500,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      Challenge(
        id: 'ch_volume_10000',
        title: 'Heavy Lifter',
        description: 'Lift 10,000 kg cumulative volume this week',
        category: 'volume',
        targetValue: 10000.0,
        rewardXP: 600,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      Challenge(
        id: 'ch_nutrition_5',
        title: 'Clean Eater',
        description: 'Meet your daily calorie/macro target 5 days this week',
        category: 'nutrition',
        targetValue: 5.0,
        rewardXP: 450,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      Challenge(
        id: 'ch_streak_4',
        title: 'Consistency King',
        description: 'Maintain a 4-day workout streak',
        category: 'streak',
        targetValue: 4.0,
        rewardXP: 400,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      Challenge(
        id: 'ch_strength_3',
        title: 'PR Crusher',
        description: 'Log 3 new personal records this week',
        category: 'strength',
        targetValue: 3.0,
        rewardXP: 550,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      Challenge(
        id: 'ch_sponsored_on_30',
        title: '30 Day Protein & Strength Challenge',
        description:
            'Complete 15 workouts and hit protein goals to unlock 25% Optimum Nutrition discount + Gold Badge.',
        category: 'training',
        targetValue: 15.0,
        rewardXP: 1000,
        startDate: startOfWeek,
        endDate: endOfWeek.add(const Duration(days: 23)),
        sponsorBrand: 'Optimum Nutrition',
        sponsorLogo:
            'https://images.unsplash.com/photo-1579722821273-0f6c7d44362f?w=200&auto=format&fit=crop&q=80',
        discountCode: 'ONPROTEIN25',
        rewardBadge: 'badge_protein_warrior',
        completionRate: 78.5,
        engagementCount: 3420,
      ),
      Challenge(
        id: 'ch_sponsored_gymshark_volume',
        title: 'Gymshark Apex Volume Challenge',
        description:
            'Lift 50,000 kg cumulative volume this month and earn an exclusive Gymshark apparel voucher.',
        category: 'volume',
        targetValue: 50000.0,
        rewardXP: 1200,
        startDate: startOfWeek,
        endDate: endOfWeek.add(const Duration(days: 23)),
        sponsorBrand: 'Gymshark',
        sponsorLogo:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=200&auto=format&fit=crop&q=80',
        discountCode: 'GYMSHARKAPEX',
        rewardBadge: 'badge_apex_lifter',
        completionRate: 64.2,
        engagementCount: 2180,
      ),
    ];
  }

  /// Get active weekly challenges.
  Future<List<Challenge>> getActiveChallenges() async {
    if (_cachedActiveChallenges != null &&
        _cachedActiveChallenges!.isNotEmpty) {
      return List.unmodifiable(_cachedActiveChallenges!);
    }

    try {
      final query = _clientManager.from('challenges');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final list = rows.map((r) => Challenge.fromJson(r)).toList();
        _cachedActiveChallenges = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}

    final defaults = _getDefaultActiveChallenges();
    _cachedActiveChallenges = defaults;
    return List.unmodifiable(defaults);
  }

  /// Get brand-sponsored fitness challenges.
  Future<List<Challenge>> getSponsoredChallenges() async {
    final all = await getActiveChallenges();
    return all.where((c) => c.isSponsored).toList();
  }

  /// Get user challenge progress records for a user.
  Future<List<UserChallenge>> getUserChallenges({
    String userId = 'usr_local',
  }) async {
    if (_cachedUserChallenges != null) {
      return List.unmodifiable(_cachedUserChallenges!);
    }

    try {
      final query = _clientManager.from('user_challenges');
      final rows = await query.select('user_id', userId);
      if (rows.isNotEmpty) {
        final list = rows.map((r) => UserChallenge.fromJson(r)).toList();
        _cachedUserChallenges = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}

    final active = await getActiveChallenges();
    final initialUserChallenges = active.map((ch) {
      return UserChallenge(
        id: 'uc_${ch.id}_$userId',
        userId: userId,
        challengeId: ch.id,
        progress: 0.0,
        completed: false,
        rewardClaimed: false,
      );
    }).toList();

    _cachedUserChallenges = initialUserChallenges;
    return List.unmodifiable(initialUserChallenges);
  }

  /// Calculate completion progress ratio (0.0 to 1.0).
  double calculateProgress(Challenge challenge, UserChallenge userChallenge) {
    if (challenge.targetValue <= 0) return 0.0;
    return (userChallenge.progress / challenge.targetValue).clamp(0.0, 1.0);
  }

  /// Automatically update user challenge progress after a completed workout.
  ///
  /// [completionKey] identifies the finished workout. A challenge that has
  /// already counted that workout is left as it is, so calling this again for
  /// the same workout (a retry) never counts it twice.
  Future<List<UserChallenge>> updateWorkoutProgress({
    required String userId,
    required WorkoutHistory workout,
    int currentStreak = 1,
    String? completionKey,
  }) async {
    final active = await getActiveChallenges();
    final userChallenges = List<UserChallenge>.from(
      await getUserChallenges(userId: userId),
    );

    for (int i = 0; i < userChallenges.length; i++) {
      final uc = userChallenges[i];
      final ch = active.firstWhere(
        (c) => c.id == uc.challengeId,
        orElse: () => Challenge(
          id: uc.challengeId,
          title: '',
          description: '',
          category: 'training',
          targetValue: 1.0,
          rewardXP: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        ),
      );

      if (completionKey != null && uc.appliedWorkoutKeys.contains(completionKey)) {
        continue;
      }
      if (uc.completed) continue;

      double newProgress = uc.progress;
      if (ch.category == 'training') {
        newProgress += 1.0;
      } else if (ch.category == 'volume') {
        newProgress += (workout.exercisesCompleted * 500.0);
      } else if (ch.category == 'streak') {
        newProgress = currentStreak.toDouble();
      } else if (ch.category == 'strength') {
        newProgress += workout.personalRecords.length.toDouble();
      }

      final isNowCompleted = newProgress >= ch.targetValue;
      userChallenges[i] = uc.copyWith(
        progress: newProgress,
        completed: isNowCompleted,
        completedAt: isNowCompleted ? (uc.completedAt ?? DateTime.now()) : null,
        appliedWorkoutKeys: completionKey == null
            ? null
            : _withKey(uc.appliedWorkoutKeys, completionKey),
      );
    }

    _cachedUserChallenges = userChallenges;
    await _persistUserChallenges(userChallenges);
    return List.unmodifiable(userChallenges);
  }

  /// Automatically update user challenge progress after nutrition goal completion.
  Future<List<UserChallenge>> updateNutritionProgress({
    required String userId,
    required double calories,
    required double protein,
    bool goalMet = true,
  }) async {
    final active = await getActiveChallenges();
    final userChallenges = List<UserChallenge>.from(
      await getUserChallenges(userId: userId),
    );

    for (int i = 0; i < userChallenges.length; i++) {
      final uc = userChallenges[i];
      final ch = active.firstWhere(
        (c) => c.id == uc.challengeId,
        orElse: () => Challenge(
          id: uc.challengeId,
          title: '',
          description: '',
          category: 'training',
          targetValue: 1.0,
          rewardXP: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        ),
      );

      if (uc.completed || ch.category != 'nutrition') continue;

      if (goalMet) {
        final newProgress = uc.progress + 1.0;
        final isNowCompleted = newProgress >= ch.targetValue;
        userChallenges[i] = uc.copyWith(
          progress: newProgress,
          completed: isNowCompleted,
          completedAt: isNowCompleted
              ? (uc.completedAt ?? DateTime.now())
              : null,
        );
      }
    }

    _cachedUserChallenges = userChallenges;
    await _persistUserChallenges(userChallenges);
    return List.unmodifiable(userChallenges);
  }

  /// Mark challenge as completed manually if needed.
  Future<UserChallenge?> completeChallenge(
    String challengeId, {
    String userId = 'usr_local',
  }) async {
    final userChallenges = List<UserChallenge>.from(
      await getUserChallenges(userId: userId),
    );
    final idx = userChallenges.indexWhere(
      (uc) => uc.challengeId == challengeId || uc.id == challengeId,
    );
    if (idx == -1) return null;

    final updated = userChallenges[idx].copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );
    userChallenges[idx] = updated;
    _cachedUserChallenges = userChallenges;
    await _persistUserChallenges(userChallenges);
    return updated;
  }

  /// Claim XP reward for a completed challenge.
  Future<UserChallenge?> claimReward(
    String challengeId, {
    String userId = 'usr_local',
  }) async {
    final userChallenges = List<UserChallenge>.from(
      await getUserChallenges(userId: userId),
    );
    final idx = userChallenges.indexWhere(
      (uc) => uc.challengeId == challengeId || uc.id == challengeId,
    );
    if (idx == -1) return null;

    final updated = userChallenges[idx].copyWith(rewardClaimed: true);
    userChallenges[idx] = updated;
    _cachedUserChallenges = userChallenges;
    await _persistUserChallenges(userChallenges);
    return updated;
  }

  Future<void> _persistUserChallenges(List<UserChallenge> list) async {
    try {
      for (final uc in list) {
        await _clientManager
            .from('user_challenges')
            .upsert(uc.toJson(), onConflictColumn: 'id');
      }
    } catch (_) {}
  }

  // --- Legacy Compatibility API ---
  static List<WeeklyChallenge> _getDefaultLegacyChallenges() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );

    return [
      WeeklyChallenge(
        id: 'weekly_consistency_5',
        title: 'Consistency Champion',
        description: 'Complete 5 workouts this week',
        category: 'Workouts',
        targetValue: 5.0,
        currentProgress: 0.0,
        xpReward: 500,
        completed: false,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      WeeklyChallenge(
        id: 'weekly_volume_10000',
        title: 'Volume Builder',
        description: 'Lift 10,000kg total volume this week',
        category: 'Volume',
        targetValue: 10000.0,
        currentProgress: 0.0,
        xpReward: 300,
        completed: false,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
      WeeklyChallenge(
        id: 'weekly_early_bird_3',
        title: 'Early Bird',
        description: 'Complete 3 workouts before 9 AM',
        category: 'Time',
        targetValue: 3.0,
        currentProgress: 0.0,
        xpReward: 200,
        completed: false,
        startDate: startOfWeek,
        endDate: endOfWeek,
      ),
    ];
  }

  /// Workout keys a challenge remembers as already counted.
  static const int _maxRememberedKeys = 20;

  static List<String> _withKey(List<String> keys, String key) {
    final all = [...keys, key];
    return all.length > _maxRememberedKeys
        ? all.sublist(all.length - _maxRememberedKeys)
        : all;
  }

  List<WeeklyChallenge> getChallenges() {
    if (_cachedLegacyChallenges != null &&
        _cachedLegacyChallenges!.isNotEmpty) {
      return List.unmodifiable(_cachedLegacyChallenges!);
    }
    final saved = LocalStorage.getWeeklyChallenges();
    if (saved.isNotEmpty) {
      _cachedLegacyChallenges = List.from(saved);
      return List.unmodifiable(saved);
    }
    final defaults = _getDefaultLegacyChallenges();
    _cachedLegacyChallenges = List.from(defaults);
    LocalStorage.saveWeeklyChallenges(defaults);
    return List.unmodifiable(defaults);
  }

  /// [completionKey] identifies the finished workout. Counting the same
  /// workout again changes nothing, and a challenge that workout completed is
  /// reported again, so a retry still pays the challenge bonus once.
  Future<List<WeeklyChallenge>> updateProgressOnWorkout(
    WorkoutHistory entry, {
    String? completionKey,
  }) async {
    final List<WeeklyChallenge> currentChallenges = List.from(getChallenges());
    final List<WeeklyChallenge> newlyCompleted = [];
    final List<WeeklyChallenge> updatedList = [];

    final double volumeAdded = entry.exercisesCompleted * 500.0;
    final bool isEarlyMorning = entry.dateCompleted.hour < 9;

    for (final challenge in currentChallenges) {
      if (completionKey != null &&
          challenge.appliedWorkoutKeys.contains(completionKey)) {
        updatedList.add(challenge);
        if (challenge.completedByKey == completionKey) {
          newlyCompleted.add(challenge);
        }
        continue;
      }
      if (challenge.completed) {
        updatedList.add(challenge);
        continue;
      }

      double progressToAdd = 0.0;
      if (challenge.id == 'weekly_consistency_5') {
        progressToAdd = 1.0;
      } else if (challenge.id == 'weekly_volume_10000') {
        progressToAdd = volumeAdded;
      } else if (challenge.id == 'weekly_early_bird_3' && isEarlyMorning) {
        progressToAdd = 1.0;
      }

      final newProgress = challenge.currentProgress + progressToAdd;
      final isNowCompleted = newProgress >= challenge.targetValue;

      final updated = challenge.copyWith(
        currentProgress: newProgress,
        completed: isNowCompleted,
        appliedWorkoutKeys: completionKey == null
            ? null
            : _withKey(challenge.appliedWorkoutKeys, completionKey),
        completedByKey: isNowCompleted ? completionKey : null,
      );

      if (isNowCompleted && !challenge.completed) {
        newlyCompleted.add(updated);
      }

      updatedList.add(updated);
    }

    _cachedLegacyChallenges = updatedList;
    LocalStorage.saveWeeklyChallenges(updatedList);
    return newlyCompleted;
  }
}
