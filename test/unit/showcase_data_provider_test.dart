import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/providers/showcase_data_provider.dart';
import 'package:atlas/services/showcase_mode_service.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShowcaseDataProvider & Dynamic Data System Unit Tests', () {
    late ShowcaseDataProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      ShowcaseModeService.resetInstance();
      ShowcaseModeProvider.resetInstance();
      ShowcaseDataProvider.resetInstance();
      provider = ShowcaseDataProvider.instance;
    });

    test('1. Generates complete athlete profile for Alex Lalremruata', () {
      final profile = provider.getShowcaseUserProfile();
      expect(profile.name, 'Alex Lalremruata');
      expect(profile.email, 'alex.rivera@atlasfit.ai');
      expect(profile.weight, '77.5');
      expect(profile.height, '178');
      expect(profile.workoutExperience, contains('Powerbuilder'));
      expect(profile.fitnessGoal, contains('Hypertrophy'));
    });

    test('2. Generates 48 workouts totaling 580,000 kg volume and verified PRs', () {
      final history = provider.getShowcaseWorkoutHistory();
      expect(history.length, 48);

      final totalVolume = history.fold<double>(0.0, (sum, w) => sum + w.totalVolume);
      expect(totalVolume, closeTo(580000.0, 1.0));

      final benchSession = history.firstWhere(
        (w) => w.personalRecords.any((pr) => pr.contains('Barbell Bench Press')),
      );
      expect(benchSession.personalRecords.first, contains('110.0 kg'));

      final deadliftSession = history.firstWhere(
        (w) => w.personalRecords.any((pr) => pr.contains('Deadlift')),
      );
      expect(deadliftSession.personalRecords.first, contains('175.0 kg'));
    });

    test('3. Generates user progress with 12-day streak and 14,850 XP', () {
      final progress = provider.getShowcaseUserProgress();
      expect(progress.completedWorkouts, 48);
      expect(progress.totalXP, 14850);
      expect(progress.workoutStreak, 12);
      expect(progress.currentRank, 'Gold');
      expect(progress.currentDivision, 'II');
      expect(progress.rankedUnlocked, isTrue);
    });

    test('4. Generates nutrition data matching 2,153 kcal and 142g protein', () {
      final nutrition = provider.getShowcaseDailyNutrition();
      expect(nutrition.meals.length, 4);
      expect(nutrition.waterLiters, 2.8);

      final totalKcal = nutrition.meals.fold<double>(
        0.0,
        (sum, m) => sum + m.totalCalories,
      );
      expect(totalKcal, closeTo(2153.0, 1.0));

      final totalProtein = nutrition.meals.fold<double>(
        0.0,
        (sum, m) => sum + m.totalProtein,
      );
      expect(totalProtein, closeTo(142.0, 1.0));
    });

    test('5. Generates recovery & readiness telemetry: 76% Readiness (GOOD), 28% Fatigue', () {
      final trainingState = provider.getShowcaseTrainingState();
      expect(trainingState.readinessScore, 76);
      expect(trainingState.fatigueScore, 28);
      expect(trainingState.recommendation, contains('Good readiness'));

      final healthMetrics = provider.getShowcaseHealthMetrics();
      expect(healthMetrics.sleepHours, 7.8);
      expect(healthMetrics.heartRateVariability, 76.0);
      expect(healthMetrics.recoveryScore, 88);
    });

    test('6. Generates 6-month weight trends from DEC to MAY', () {
      final summary = provider.getShowcaseWeightTrendSummary();
      expect(summary.currentKg, 72.4);
      expect(summary.changeKg, -1.2);
      expect(summary.lowestKg, 68.7);
      expect(summary.highestKg, 75.1);
      expect(summary.points.length, 6);

      expect(summary.points.first.label, 'DEC');
      expect(summary.points.first.weightKg, 68.7);

      expect(summary.points.last.label, 'MAY');
      expect(summary.points.last.weightKg, 72.4);
    });

    test('7. ShowcaseModeService delegates seamlessly to ShowcaseDataProvider', () {
      final service = ShowcaseModeService.instance;
      expect(service.getShowcaseUserProfile().name, 'Alex Lalremruata');
      expect(service.getShowcaseWorkoutHistory().length, 48);
      expect(service.getShowcaseDailyNutrition().waterLiters, 2.8);
      expect(service.getShowcaseTrainingState().readinessScore, 76);
      expect(service.getShowcaseWeightTrendSummary().currentKg, 72.4);
    });
  });
}
