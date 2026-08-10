import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/challenge.dart';
import 'package:aizawl_gym/models/user_challenge.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/challenge_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    ChallengeService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('Challenge & UserChallenge Models Unit Tests', () {
    test('Challenge serialization, copyWith, and isActive evaluation', () {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 2));
      final end = now.add(const Duration(days: 5));

      final challenge = Challenge(
        id: 'c1',
        title: 'Weekly Iron Warrior',
        description: 'Complete 5 workouts',
        category: 'training',
        targetValue: 5.0,
        rewardXP: 500,
        startDate: start,
        endDate: end,
      );

      expect(challenge.isActive, isTrue);
      expect(challenge.countdownLabel, contains('left'));

      final json = challenge.toJson();
      expect(json['id'], equals('c1'));
      expect(json['category'], equals('training'));
      expect(json['reward_xp'], equals(500));

      final parsed = Challenge.fromJson(json);
      expect(parsed.id, equals('c1'));
      expect(parsed.rewardXP, equals(500));
    });

    test('UserChallenge serialization, copyWith, and equality', () {
      final uc = UserChallenge(
        id: 'uc1',
        userId: 'u1',
        challengeId: 'c1',
        progress: 3.0,
        completed: false,
        rewardClaimed: false,
      );

      final json = uc.toJson();
      expect(json['id'], equals('uc1'));
      expect(json['current_progress'], equals(3.0));

      final updated = uc.copyWith(progress: 5.0, completed: true);
      expect(updated.progress, equals(5.0));
      expect(updated.completed, isTrue);
    });
  });

  group('ChallengeService Unit Tests', () {
    test('getActiveChallenges returns initial active challenge list', () async {
      final service = ChallengeService.instance;
      final active = await service.getActiveChallenges();

      expect(active, isNotEmpty);
      expect(active.any((c) => c.category == 'training'), isTrue);
    });

    test('calculateProgress calculates ratio clamped to 1.0', () {
      final service = ChallengeService.instance;
      final ch = Challenge(
        id: 'c1',
        title: 'Test',
        description: 'Test',
        category: 'training',
        targetValue: 5.0,
        rewardXP: 100,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      final ucHalf = UserChallenge(id: 'uc1', userId: 'u1', challengeId: 'c1', progress: 2.5);
      expect(service.calculateProgress(ch, ucHalf), equals(0.5));

      final ucOver = UserChallenge(id: 'uc2', userId: 'u1', challengeId: 'c1', progress: 10.0);
      expect(service.calculateProgress(ch, ucOver), equals(1.0));
    });

    test('updateWorkoutProgress automatically updates training challenge progress', () async {
      final service = ChallengeService.instance;
      final workout = WorkoutHistory(
        workoutName: 'Chest Press',
        dateCompleted: DateTime.now(),
        durationSeconds: 1800,
        exercisesCompleted: 4,
        completionPercentage: 1.0,
        totalVolume: 2000.0,
        caloriesBurned: 300.0,
        xpEarned: 150,
      );

      final updatedUCs = await service.updateWorkoutProgress(
        userId: 'usr_test',
        workout: workout,
      );

      expect(updatedUCs, isNotEmpty);
      final trainingUC = updatedUCs.firstWhere((u) => u.challengeId == 'ch_training_5');
      expect(trainingUC.progress, equals(1.0));
    });

    test('claimReward marks rewardClaimed as true', () async {
      final service = ChallengeService.instance;
      await service.completeChallenge('ch_training_5', userId: 'usr_test');
      final claimed = await service.claimReward('ch_training_5', userId: 'usr_test');

      expect(claimed, isNotNull);
      expect(claimed!.rewardClaimed, isTrue);
    });
  });

  group('FitnessProvider Challenge Integration Tests', () {
    test('loadChallenges populates active and user challenge lists', () async {
      final provider = FitnessProvider.instance;
      expect(provider.activeChallenges.isEmpty, isTrue);

      await provider.loadChallenges();

      expect(provider.activeChallenges, isNotEmpty);
      expect(provider.userChallenges, isNotEmpty);
      expect(provider.isChallengesLoading, isFalse);
    });

    test('claimChallengeReward increases user total XP', () async {
      final provider = FitnessProvider.instance;
      await provider.loadChallenges();

      final initialXP = provider.totalXP;
      final ch = provider.activeChallenges.first;

      // Complete challenge first
      await ChallengeService.instance.completeChallenge(ch.id, userId: provider.currentUser?.id ?? 'usr_local');
      await provider.loadChallenges();

      final success = await provider.claimChallengeReward(ch.id);
      expect(success, isTrue);
      expect(provider.totalXP, equals(initialXP + ch.rewardXP));
    });
  });
}
