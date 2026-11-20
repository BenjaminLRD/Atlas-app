import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/services/showcase_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Showcase Mode Global Demo Data Toggle Architecture', () {
    late ShowcaseModeProvider showcaseProvider;
    late FitnessProvider fitnessProvider;
    late ProfileProvider profileProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      ShowcaseModeService.resetInstance();
      ShowcaseModeProvider.resetInstance();
      showcaseProvider = ShowcaseModeProvider.instance;
      fitnessProvider = FitnessProvider.instance;
      profileProvider = AppDependencies.instance.profileProvider;
    });

    test('1. Initial State: Showcase Mode is disabled by default', () {
      expect(showcaseProvider.isShowcaseModeEnabled, isFalse);
      expect(LocalStorage.isShowcaseModeEnabled(), isFalse);
    });

    test(
      '2. Enable Showcase Mode: Injects demo athlete data across all layers',
      () async {
        await showcaseProvider.enableShowcaseMode();

        expect(showcaseProvider.isShowcaseModeEnabled, isTrue);
        expect(LocalStorage.isShowcaseModeEnabled(), isTrue);

        // Verify ProfileProvider has switched to Alex Lalremruata
        expect(profileProvider.name, 'Alex Lalremruata');
        expect(profileProvider.weight, '77.5');
        expect(profileProvider.height, '178');
        expect(profileProvider.workoutExperience, contains('Powerbuilder'));

        // Verify FitnessProvider Workout History (48 workouts, 580k volume, PRs)
        expect(fitnessProvider.workoutHistory.length, 48);
        final totalVolume = fitnessProvider.workoutHistory.fold(
          0.0,
          (sum, w) => sum + w.totalVolume,
        );
        expect(totalVolume, closeTo(580000.0, 1.0));
        expect(fitnessProvider.userProgress.workoutStreak, 12);
        expect(fitnessProvider.userProgress.longestStreak, 30);
        expect(fitnessProvider.userProgress.currentRank, 'Gold');
        expect(fitnessProvider.userProgress.currentDivision, 'II');
        expect(fitnessProvider.userProgress.totalXP, 14850);

        // Verify PRs
        final recentPRs = fitnessProvider.workoutHistory.first.personalRecords;
        expect(recentPRs.any((pr) => pr.contains('110.0 kg')), isTrue);

        // Verify Nutrition: 2,153 / 2,300 kcal, 142g / 185g Protein
        final dailyNutr = fitnessProvider.todayNutrition;
        expect(dailyNutr.targets.calories, 2300.0);
        expect(dailyNutr.targets.proteinGrams, 185.0);
        expect(dailyNutr.totalCaloriesConsumed, 2153.0);
        expect(dailyNutr.totalProteinConsumed, 142.0);
        expect(dailyNutr.totalCarbsConsumed, 238.0);
        expect(dailyNutr.totalFatConsumed, 63.0);
        expect(dailyNutr.meals.length, 4);

        // Verify Recovery & Health Telemetry: 88 Readiness, 7h 48m sleep, 76ms HRV, 52 HR
        final health = fitnessProvider.todayHealthMetrics;
        expect(health?.recoveryScore, 88);
        expect(health?.sleepHours, 7.8);
        expect(health?.heartRateVariability, 76.0);
        expect(health?.restingHeartRate, 52.0);

        // Verify AI Coach Messages & Recommendations
        expect(fitnessProvider.coachMessages.length, greaterThanOrEqualTo(4));
        expect(fitnessProvider.recommendations.length, greaterThanOrEqualTo(2));
      },
    );

    test('3. Disable Showcase Mode: Cleanly restores real user data', () async {
      // First enable showcase mode
      await showcaseProvider.enableShowcaseMode();
      expect(showcaseProvider.isShowcaseModeEnabled, isTrue);

      // Now disable showcase mode
      await showcaseProvider.disableShowcaseMode();
      expect(showcaseProvider.isShowcaseModeEnabled, isFalse);
      expect(LocalStorage.isShowcaseModeEnabled(), isFalse);

      // Verify ProfileProvider has restored default/real user profile
      expect(profileProvider.name, isNot('Alex Lalremruata'));
    });

    test(
      '4. Toggle Showcase Mode: Toggles seamlessly between states',
      () async {
        expect(showcaseProvider.isShowcaseModeEnabled, isFalse);

        await showcaseProvider.toggleShowcaseMode();
        expect(showcaseProvider.isShowcaseModeEnabled, isTrue);
        expect(profileProvider.name, 'Alex Lalremruata');

        await showcaseProvider.toggleShowcaseMode();
        expect(showcaseProvider.isShowcaseModeEnabled, isFalse);
        expect(profileProvider.name, isNot('Alex Lalremruata'));
      },
    );
  });
}
