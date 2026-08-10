import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/fitness_season.dart';
import 'package:aizawl_gym/models/season_progress.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/season_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    SeasonService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('FitnessSeason & SeasonProgress Models Unit Tests', () {
    test('FitnessSeason active status and remaining days getters', () {
      final now = DateTime.now();
      final season = FitnessSeason(
        id: 's_active',
        name: 'Monsoon Mayhem',
        description: 'Season 3',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
        rewardDescription: 'Golden Trophy Badge',
      );

      expect(season.isActive, isTrue);
      expect(season.remainingDays, greaterThanOrEqualTo(24));

      final json = season.toJson();
      expect(json['id'], equals('s_active'));
      expect(json['name'], equals('Monsoon Mayhem'));
    });

    test('SeasonProgress serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final prog = SeasonProgress(
        id: 'sp_1',
        seasonId: 'season_1',
        userId: 'usr_1',
        seasonXP: 2500,
        updatedAt: now,
      );

      final json = prog.toJson();
      expect(json['season_xp'], equals(2500));

      final updated = prog.copyWith(seasonXP: 3000);
      expect(updated.seasonXP, equals(3000));
    });
  });

  group('SeasonService Unit Tests', () {
    test('getCurrentSeason returns active season', () async {
      final service = SeasonService.instance;
      final season = await service.getCurrentSeason();

      expect(season.id, isNotEmpty);
      expect(season.isActive, isTrue);
    });

    test('addSeasonXP updates season progress and leaderboard sorting', () async {
      final service = SeasonService.instance;
      final season = await service.getCurrentSeason();

      final updated = await service.addSeasonXP(
        seasonId: season.id,
        userId: 'usr_local',
        amount: 500,
      );

      expect(updated.seasonXP, greaterThanOrEqualTo(500));

      final leaderboard = await service.getSeasonLeaderboard(season.id);
      expect(leaderboard, isNotEmpty);
      expect(leaderboard.first.totalXP, greaterThanOrEqualTo(leaderboard.last.totalXP));
    });
  });

  group('FitnessProvider Season Integration Tests', () {
    test('loadSeason populates currentSeason and seasonProgress', () async {
      final provider = FitnessProvider.instance;
      await provider.loadSeason();

      expect(provider.currentSeason, isNotNull);
      expect(provider.seasonProgress, isNotNull);
      expect(provider.seasonLeaderboard, isNotEmpty);
    });

    test('saveWorkoutCompletion accumulates seasonal XP', () async {
      final provider = FitnessProvider.instance;
      await provider.loadSeason();
      final initialXP = provider.seasonProgress?.seasonXP ?? 0;

      final workout = WorkoutHistory(
        workoutName: 'Seasonal Heavy Deadlifts',
        dateCompleted: DateTime.now(),
        durationSeconds: 3000,
        exercisesCompleted: 6,
        completionPercentage: 1.0,
        totalVolume: 6500.0,
        caloriesBurned: 450.0,
        xpEarned: 200,
      );

      await provider.saveWorkoutCompletion(workout);
      await provider.loadSeason();

      expect(provider.seasonProgress?.seasonXP, greaterThan(initialXP));
    });
  });
}
