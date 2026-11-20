import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:atlas/services/health/platform_health_reader.dart';
import '../mocks/fake_health_data_source.dart';
import 'package:atlas/services/wearables/health_connect_wearable_service.dart';
import 'package:atlas/services/wearables/health_kit_wearable_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/health_metrics.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/recommended_workout.dart';
import 'package:atlas/models/recovery/training_readiness_score.dart';
import 'package:atlas/models/workout_feedback.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/recovery/health_prediction_engine.dart';
import 'package:atlas/services/recovery/recovery_prediction_engine.dart';
import 'package:atlas/services/recovery/training_load_engine.dart';
import 'package:atlas/services/wearables/wearable_service.dart';
import 'package:atlas/services/workout_adaptation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrainingLoadEngine trainingLoadEngine;
  late RecoveryPredictionEngine recoveryEngine;
  late HealthPredictionEngine healthPredictionEngine;
  late WorkoutAdaptationService adaptationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    trainingLoadEngine = const TrainingLoadEngine();
    recoveryEngine = RecoveryPredictionEngine(
      trainingLoadEngine: trainingLoadEngine,
    );
    healthPredictionEngine = HealthPredictionEngine(
      recoveryPredictionEngine: recoveryEngine,
    );
    adaptationService = WorkoutAdaptationService();
  });

  group('1. Health Metrics Model Tests', () {
    test('HealthMetrics serializes, deserializes, and copies correctly', () {
      final metric = HealthMetrics(
        id: 'hm_001',
        userId: 'usr_athlete',
        timestamp: DateTime(2026, 8, 26, 8, 30),
        sleepHours: 8.2,
        restingHeartRate: 56.0,
        heartRateVariability: 74.0,
        steps: 10450,
        stressLevel: 15.0,
        recoveryScore: 92,
        sourceDevice: 'Garmin Forerunner',
      );

      final json = metric.toJson();
      final decoded = HealthMetrics.fromJson(json);

      expect(decoded.id, equals('hm_001'));
      expect(decoded.userId, equals('usr_athlete'));
      expect(decoded.sleepHours, equals(8.2));
      expect(decoded.restingHeartRate, equals(56.0));
      expect(decoded.heartRateVariability, equals(74.0));
      expect(decoded.steps, equals(10450));
      expect(decoded.stressLevel, equals(15.0));
      expect(decoded.recoveryScore, equals(92));
      expect(decoded.sourceDevice, equals('Garmin Forerunner'));

      final copy = metric.copyWith(sleepHours: 7.0);
      expect(copy.sleepHours, equals(7.0));
      expect(copy.id, equals('hm_001'));
    });
  });

  group('2. Training Load Engine Tests (ATL, CTL, ACWR, TSB)', () {
    test('Calculates ATL over 7 days and CTL over 28 days', () {
      final now = DateTime(2026, 8, 26);
      final workouts = [
        WorkoutHistory(
          workoutName: 'Heavy Leg Day',
          dateCompleted: now.subtract(const Duration(days: 1)),
          durationSeconds: 3600,
          totalVolume: 5000.0,
          caloriesBurned: 450,
          exercisesCompleted: 5,
          completionPercentage: 1.0,
        ),
        WorkoutHistory(
          workoutName: 'Chest & Arms',
          dateCompleted: now.subtract(const Duration(days: 3)),
          durationSeconds: 3000,
          totalVolume: 4000.0,
          caloriesBurned: 380,
          exercisesCompleted: 5,
          completionPercentage: 1.0,
        ),
        WorkoutHistory(
          workoutName: 'Back & Deadlift',
          dateCompleted: now.subtract(const Duration(days: 14)),
          durationSeconds: 3300,
          totalVolume: 6000.0,
          caloriesBurned: 420,
          exercisesCompleted: 4,
          completionPercentage: 1.0,
        ),
        WorkoutHistory(
          workoutName: 'Shoulder Press',
          dateCompleted: now.subtract(const Duration(days: 21)),
          durationSeconds: 2700,
          totalVolume: 3000.0,
          caloriesBurned: 300,
          exercisesCompleted: 4,
          completionPercentage: 1.0,
        ),
      ];

      final atl = trainingLoadEngine.calculateAcuteTrainingLoad(
        workouts,
        referenceDate: now,
      );
      expect(atl, equals(9000.0)); // w1 (5000) + w2 (4000)

      final ctl = trainingLoadEngine.calculateChronicTrainingLoad(
        workouts,
        referenceDate: now,
      );
      // Total 28-day volume = 5000 + 4000 + 6000 + 3000 = 18000. CTL (weekly avg) = 18000 / 4 = 4500.0
      expect(ctl, equals(4500.0));

      final acwr = trainingLoadEngine.calculateACWR(
        acuteLoad: atl,
        chronicLoad: ctl,
      );
      expect(acwr, equals(2.0)); // 9000 / 4500 = 2.0 (Volume spike)

      final isSpike = trainingLoadEngine.isVolumeSpike(acwr);
      expect(isSpike, isTrue);

      final tsb = trainingLoadEngine.calculateTSB(
        acuteLoad: atl,
        chronicLoad: ctl,
      );
      expect(tsb, equals(-4500.0)); // Fatigue state
    });

    test('Identifies optimal ACWR in sweet spot (0.8 - 1.3)', () {
      final acwr = trainingLoadEngine.calculateACWR(
        acuteLoad: 5000.0,
        chronicLoad: 4500.0,
      );
      expect(acwr, closeTo(1.11, 0.05));
      expect(trainingLoadEngine.isVolumeSpike(acwr), isFalse);
    });
  });

  group('3. Recovery Prediction Engine Tests (5-Factor Weighted Score)', () {
    test(
      'Calculates High Readiness (>= 70) for well-rested, well-fueled athlete',
      () {
        final now = DateTime(2026, 8, 26, 10, 0);
        final workoutHistory = [
          WorkoutHistory(
            workoutName: 'Upper Body',
            dateCompleted: now.subtract(
              const Duration(hours: 36),
            ), // Rested 36h
            durationSeconds: 3000,
            totalVolume: 4000.0,
            caloriesBurned: 350,
            exercisesCompleted: 4,
            completionPercentage: 1.0,
          ),
        ];

        final healthMetrics = HealthMetrics(
          id: 'hm1',
          timestamp: now,
          sleepHours: 8.0, // 100%
          heartRateVariability: 75.0, // 100%
          restingHeartRate: 55.0,
        );

        const nutrition = DailyNutrition(
          date: '2026-08-26',
          targets: MacroTarget(
            calories: 2200,
            proteinGrams: 140,
            carbsGrams: 250,
            fatGrams: 70,
          ),
          meals: [],
          baseCalories: 2000.0,
          baseProtein: 130.0,
        );

        final report = recoveryEngine.analyzeReadiness(
          userId: 'usr_athlete',
          workoutHistory: workoutHistory,
          healthMetrics: healthMetrics,
          todayNutrition: nutrition,
          referenceDate: now,
        );

        expect(report.readinessScore.score, greaterThanOrEqualTo(80.0));
        expect(report.readinessScore.status, equals('Ready to Train'));
        expect(report.fatigueLevel, equals('low'));
        expect(report.isDeloadRecommended, isFalse);
        expect(report.trainHardAnswer, contains('Yes!'));
      },
    );

    test(
      'Calculates Low Readiness (< 50) and recommends deload on poor sleep and volume spike',
      () {
        final now = DateTime(2026, 8, 26, 8, 0);
        final workoutHistory = [
          WorkoutHistory(
            workoutName: 'Heavy Legs',
            dateCompleted: now.subtract(
              const Duration(hours: 8),
            ), // Only 8h rest
            durationSeconds: 5400,
            totalVolume: 12000.0, // Massive acute volume
            caloriesBurned: 700,
            exercisesCompleted: 6,
            completionPercentage: 1.0,
          ),
        ];

        final healthMetrics = HealthMetrics(
          id: 'hm2',
          timestamp: now,
          sleepHours: 4.5, // Severe sleep deprivation
          heartRateVariability: 32.0, // Sympathetic strain
          restingHeartRate: 75.0,
        );

        final feedbackHistory = [
          WorkoutFeedback(
            id: 'fb1',
            workoutId: 'w1',
            difficultyRating: 'too_hard',
            createdAt: now.subtract(const Duration(hours: 8)),
          ),
        ];

        final report = recoveryEngine.analyzeReadiness(
          userId: 'usr_athlete',
          workoutHistory: workoutHistory,
          healthMetrics: healthMetrics,
          feedbackHistory: feedbackHistory,
          referenceDate: now,
        );

        expect(report.readinessScore.score, lessThan(50.0));
        expect(report.readinessScore.status, equals('Recovery Recommended'));
        expect(report.readinessScore.readinessGrade, equals('Deload'));
        expect(report.isDeloadRecommended, isTrue);
        expect(report.suggestedVolumeAdjustmentPercent, equals(-50.0));
        expect(report.trainHardAnswer, contains('No:'));
      },
    );
  });

  group('4. Adaptive Workout System Integration Tests', () {
    test('WorkoutAdaptationService scales volume based on readiness', () {
      final originalWorkout = RecommendedWorkout(
        id: 'w_rec_01',
        title: 'Push Hypertrophy',
        focusMuscleGroups: const ['Chest'],
        intensity: 'heavy',
        reason: 'Scheduled Push Day',
        exercises: const [
          'Bench Press',
          'Overhead Press',
          'Incline DB Press',
          'Tricep Pushdown',
        ],
        structuredExercises: const [
          {'name': 'Bench Press', 'sets': 4, 'reps': '8-10'},
          {'name': 'Overhead Press', 'sets': 4, 'reps': '8-10'},
          {'name': 'Incline DB Press', 'sets': 3, 'reps': '10-12'},
          {'name': 'Tricep Pushdown', 'sets': 3, 'reps': '12-15'},
        ],
      );

      // 1. High Readiness: no volume change
      final highReadiness = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true, hasWorkoutHistory: true),
        workoutRecovery: 90,
        sleepScore: 90,
        hrvScore: 90,
        trainingLoadScore: 90,
        nutritionScore: 90,
      );
      final highAdapted = adaptationService.adaptWorkoutForReadiness(
        workout: originalWorkout,
        readiness: highReadiness,
      );
      expect(highAdapted.structuredExercises.first['sets'], equals(4));

      // 2. Moderate Readiness (50-69): -1 set per exercise
      final modReadiness = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true, hasWorkoutHistory: true),
        workoutRecovery: 60,
        sleepScore: 60,
        hrvScore: 60,
        trainingLoadScore: 60,
        nutritionScore: 60,
      );
      final modAdapted = adaptationService.adaptWorkoutForReadiness(
        workout: originalWorkout,
        readiness: modReadiness,
      );
      expect(
        modAdapted.structuredExercises.first['sets'],
        equals(3),
      ); // 4 - 1 = 3

      // 3. Low Readiness (< 50): -50% sets & light intensity
      final lowReadiness = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true, hasWorkoutHistory: true),
        workoutRecovery: 30,
        sleepScore: 30,
        hrvScore: 30,
        trainingLoadScore: 30,
        nutritionScore: 30,
      );
      final lowAdapted = adaptationService.adaptWorkoutForReadiness(
        workout: originalWorkout,
        readiness: lowReadiness,
      );
      expect(
        lowAdapted.structuredExercises.first['sets'],
        equals(2),
      ); // 4 * 0.5 = 2
      expect(lowAdapted.intensity, equals('light'));
      expect(lowAdapted.reason, contains('Deload active'));
    });
  });

  group('5. AI Coach Prompt Recovery Intelligence Context Tests', () {
    test('CoachPromptBuilder includes [RECOVERY INTELLIGENCE CONTEXT]', () {
      const builder = CoachPromptBuilder();
      final context = FitnessContext.initial();

      final prompt = builder.buildPrompt(
        message: 'Should I do heavy squats today?',
        context: context,
      );

      expect(prompt.contains('[RECOVERY INTELLIGENCE CONTEXT]'), isTrue);
      expect(prompt.contains('Training Readiness:'), isTrue);
      expect(prompt.contains('Recovery Recommendation:'), isTrue);
    });
  });

  group('6. Wearable Service & Multi-Platform Abstraction Tests', () {
    test(
      'UniversalWearableManager synchronizes from selected wearable platform',
      () async {
        PlatformHealthReader.setInstance(
          PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Test Watch'),
            isIOS: false,
          ),
        );
        addTearDown(PlatformHealthReader.resetInstance);
        final manager = UniversalWearableManager.instance;
        manager.setActivePlatform(WearablePlatform.googleFit);

        final metrics = await manager.syncActiveDevice(
          userId: 'usr_watch_athlete',
        );
        expect(metrics, isNotNull);
        expect(metrics!.sourceDevice, contains('Test Watch'));
        expect(metrics.steps, 8432);
        expect(metrics.sleepHours, isNotNull);
      },
    );

    test('Apple Health and Health Connect services sync telemetry', () async {
      final apple = HealthKitWearableService(
        reader: PlatformHealthReader(
          FakeHealthDataSource.withTypicalDay(source: 'Apple Watch'),
          isIOS: true,
        ),
      );
      final appleMetrics = await apple.syncHealthData(userId: 'usr_ios');
      expect(appleMetrics!.sourceDevice, contains('Apple Watch'));

      final android = HealthConnectWearableService(
        reader: PlatformHealthReader(
          FakeHealthDataSource.withTypicalDay(source: 'Pixel Watch'),
          isIOS: false,
        ),
      );
      final androidMetrics = await android.syncHealthData(
        userId: 'usr_android',
      );
      expect(androidMetrics!.sourceDevice, contains('Pixel Watch'));
    });
  });

  group('7. Health Prediction Engine & ML Foundation Tests', () {
    test(
      'HealthPredictionEngine executes ML model forward pass and produces RecoveryReport',
      () async {
        final report = await healthPredictionEngine.predictRecoveryAndReadiness(
          userId: 'usr_athlete_ml',
          workoutHistory: const [],
          healthMetrics: HealthMetrics(
            id: 'hm_ml',
            timestamp: DateTime.now(),
            sleepHours: 7.8,
            heartRateVariability: 68.0,
          ),
        );

        expect(report.readinessScore.score, greaterThan(0.0));
        expect(report.recommendation.isNotEmpty, isTrue);
      },
    );
  });

  group('8. FitnessProvider & LocalStorage End-to-End Integration Tests', () {
    test(
      'FitnessProvider evaluates readiness and stores report to LocalStorage',
      () async {
        final provider = FitnessProvider();

        final report = await provider.evaluateTrainingReadiness();
        expect(report, isNotNull);
        expect(provider.latestRecoveryReport, isNotNull);

        final cached = LocalStorage.getLatestRecoveryReport();
        expect(cached, isNotNull);
        expect(cached!.id, equals(report.id));
      },
    );

    test(
      'FitnessProvider syncs wearable telemetry and auto-recalculates readiness',
      () async {
        PlatformHealthReader.setInstance(
          PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Test Watch'),
            isIOS: false,
          ),
        );
        addTearDown(PlatformHealthReader.resetInstance);
        final provider = FitnessProvider();

        final metric = await provider.syncWearableHealthData(
          platform: WearablePlatform.googleFit,
        );
        expect(metric, isNotNull);
        expect(provider.todayHealthMetrics, isNotNull);
        expect(provider.todayHealthMetrics!.sourceDevice, contains('Test Watch'));

        final storedMetrics = LocalStorage.getHealthMetricsList();
        expect(storedMetrics.isNotEmpty, isTrue);
      },
    );
  });
}
