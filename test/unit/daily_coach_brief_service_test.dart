import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_action.dart';
import 'package:atlas/models/daily_coach_brief.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/health_metrics.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/models/workout_recommendation.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/daily_coach_brief_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DailyCoachBriefService briefService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    briefService = DailyCoachBriefService();
  });

  group('DailyCoachBriefService — Autonomous Proactive AI Coach 2.0', () {
    test(
      'generateBrief synthesizes recovery, sleep, workout split, and nutrition delta',
      () {
        final now = DateTime.now();
        final context = FitnessContext(
          userProfile: UserProfile.defaultProfile().copyWith(name: 'Alex'),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          userGoal: UserGoal.initial(),
          weightGoal: WeightGoal(
            id: 'wg_01',
            userId: 'usr_01',
            currentWeight: 75.0,
            targetWeight: 80.0,
            targetWeeks: 12,
            type: WeightGoalType.gain,
            diet: DietPreference.noRestrictions,
            mealsPerDay: MealFrequency.fourMeals,
            dailyCalorieTarget: 2800,
            proteinGrams: 160,
            carbsGrams: 350,
            fatGrams: 75,
            expectedWeeklyRateKg: 0.5,
            createdAt: now,
            updatedAt: now,
          ),
          progressSummary: ProgressSummary.zero(),
          nutritionSummary: const NutritionSummary(
            averageProtein: 135.0, // 25g below 160g target
            averageDailyCalories: 2400.0,
          ),
          workoutHistory: const [],
          generatedAt: now,
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_01',
            recoveryScore: 82,
            fatigueLevel: FatigueLevel.low,
            sleepQuality: 0.88,
            lastUpdated: now,
          ),
        );

        final healthMetrics = HealthMetrics(
          id: 'hm_01',
          date: now,
          sleepHours: 7.5,
          restingHeartRate: 58.0,
          hrv: 62.0,
        );

        final morningTime = DateTime(2026, 8, 24, 8, 30);
        final brief = briefService.generateBrief(
          context: context,
          healthMetrics: healthMetrics,
          date: morningTime,
        );

        // Verify Greeting
        expect(brief.greeting, 'Good morning, Alex.');

        // Verify Recovery
        expect(brief.recovery.recoveryScore, 82);
        expect(brief.recovery.sleepHours, 7.5);
        expect(brief.recovery.readinessCategory, 'Optimal');

        // Verify Workout
        expect(brief.workout.isRestDay, isFalse);
        expect(brief.workout.splitType, 'push');

        // Verify Coach Actions
        expect(brief.actions.length, greaterThanOrEqualTo(2));
        final workoutAction = brief.actions.firstWhere(
          (a) => a.category == 'workout',
        );
        expect(workoutAction.priority, CoachActionPriority.high);

        final nutritionAction = brief.actions.firstWhere(
          (a) => a.category == 'nutrition',
        );
        expect(nutritionAction.priority, CoachActionPriority.high);
        expect(
          nutritionAction.description.contains('25g below target'),
          isTrue,
        );

        // Verify Autonomous Coaching Proactive Narrative
        expect(brief.proactiveMessage.contains('Good morning, Alex.'), isTrue);
        expect(
          brief.proactiveMessage.contains('recovery score is 82%'),
          isTrue,
        );
        expect(brief.proactiveMessage.contains('slept 7.5 hours'), isTrue);
        expect(
          brief.proactiveMessage.contains('push workout is scheduled today'),
          isTrue,
        );
        expect(
          brief.proactiveMessage.contains(
            'protein intake yesterday was 25g below target',
          ),
          isTrue,
        );
        expect(brief.proactiveMessage.contains('Recommendation:'), isTrue);
        expect(
          brief.proactiveMessage.contains('add a high-protein breakfast'),
          isTrue,
        );
      },
    );

    test(
      'generateBrief adapts to Rest Day when fatigue is critical or deload recommended',
      () {
        final now = DateTime.now();
        final context = FitnessContext(
          userProfile: UserProfile.defaultProfile().copyWith(name: 'Sarah'),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          userGoal: UserGoal.initial(),
          progressSummary: ProgressSummary.zero(),
          nutritionSummary: const NutritionSummary(averageProtein: 150.0),
          workoutHistory: const [],
          generatedAt: now,
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_crit',
            recoveryScore: 35,
            fatigueLevel: FatigueLevel.critical,
            isDeloadRecommended: true,
            lastUpdated: now,
          ),
        );

        final brief = briefService.generateBrief(
          context: context,
          date: DateTime(2026, 8, 24, 14, 0), // Afternoon
        );

        expect(brief.greeting, 'Good afternoon, Sarah.');
        expect(brief.recovery.isDeloadRecommended, isTrue);
        expect(brief.recovery.readinessCategory, 'Critical');
        expect(brief.workout.isRestDay, isTrue);
        expect(brief.workout.intensityLevel, 'Rest');

        final recoveryAction = brief.actions.firstWhere(
          (a) => a.category == 'recovery',
        );
        expect(recoveryAction.actionRoute, 'open_recovery');
        expect(brief.proactiveMessage.contains('active recovery day'), isTrue);
      },
    );
  });

  group('DailyCoachBrief Domain Models & JSON Serialization', () {
    test(
      'DailyCoachBrief roundtrip JSON serialization preserves all nested objects',
      () {
        final now = DateTime.now();
        final original = DailyCoachBrief(
          date: now,
          greeting: 'Good evening, Master Chief.',
          actions: [
            CoachAction(
              id: 'act_01',
              title: 'Bench Press Session',
              description: 'Heavy 5x5 protocol',
              category: 'workout',
              priority: CoachActionPriority.high,
              actionRoute: 'open_workout',
              actionLabel: 'Lift Now',
              isCompleted: false,
              createdAt: now,
            ),
          ],
          recovery: const RecoverySummary(isMeasured: true, recoveryScore: 90,
            sleepHours: 8.2,
            readinessCategory: 'Optimal',
          ),
          nutrition: const NutritionSummary(
            averageProtein: 180.0,
            averageDailyCalories: 3100.0,
          ),
          workout: const WorkoutRecommendation(
            id: 'rec_01',
            workoutTitle: 'Heavy Chest & Triceps',
            splitType: 'push',
            focusMuscles: ['Chest', 'Triceps'],
            estimatedDurationMinutes: 50,
            estimatedCalories: 400.0,
            exerciseCount: 5,
          ),
          progress: ProgressSummary.zero(),
          proactiveMessage: 'Target lock engaged. Ready for push day.',
        );

        final json = original.toJson();
        final restored = DailyCoachBrief.fromJson(json);

        expect(restored.greeting, original.greeting);
        expect(restored.proactiveMessage, original.proactiveMessage);
        expect(restored.actions.length, 1);
        expect(restored.actions.first.title, 'Bench Press Session');
        expect(restored.recovery.recoveryScore, 90);
        expect(restored.recovery.sleepHours, 8.2);
        expect(restored.workout.workoutTitle, 'Heavy Chest & Triceps');
        expect(restored.workout.splitType, 'push');
      },
    );

    test('DailyCoachBrief.empty creates valid zero-state defaults', () {
      final emptyBrief = DailyCoachBrief.empty();
      expect(emptyBrief.greeting, contains('Athlete'));
      expect(emptyBrief.recovery.recoveryScore, 80);
      expect(emptyBrief.workout.isRestDay, isTrue);
      expect(emptyBrief.actions, isEmpty);
      expect(emptyBrief.proactiveMessage, isNotEmpty);
    });
  });

  group('FitnessProvider — AI Coach 2.0 Integration', () {
    test('FitnessProvider provides reactive dailyCoachBrief', () {
      final provider = FitnessProvider();
      final brief = provider.dailyCoachBrief;

      expect(brief, isNotNull);
      expect(brief.greeting, isNotEmpty);
      expect(brief.recovery, isNotNull);
      expect(brief.workout, isNotNull);
      expect(brief.proactiveMessage, isNotEmpty);

      // Verify manual refresh
      final refreshed = provider.refreshDailyCoachBrief();
      expect(refreshed, isNotNull);
    });
  });
}
