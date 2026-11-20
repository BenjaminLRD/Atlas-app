import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:atlas/services/health/platform_health_reader.dart';
import '../mocks/fake_health_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/wearables/health_connect_wearable_service.dart';
import 'package:atlas/services/wearables/health_kit_wearable_service.dart';

void main() {
  group('Phase 10: Advanced Wearables & Recovery Intelligence Test Suite', () {
    test('1. HealthMetric model parses and serializes complete telemetry', () {
      final sample = HealthMetric.sample();
      expect(sample.steps, equals(8432));
      expect(sample.distance, equals(5.2));
      expect(sample.activeCalories, equals(520.0));
      expect(sample.restingHeartRate, equals(64));
      expect(sample.averageHeartRate, equals(72));
      expect(sample.heartRateVariability, equals(68.0));
      expect(sample.sleepDuration, equals(440));
      expect(sample.deepSleep, equals(95));
      expect(sample.sleepQuality, equals(88.0));
      expect(sample.stressScore, equals(18.0));
      expect(sample.trainingLoad, equals(420.0));

      final json = sample.toJson();
      final roundTrip = HealthMetric.fromJson(json);
      expect(roundTrip.steps, equals(8432));
      expect(roundTrip.heartRateVariability, equals(68.0));
      expect(roundTrip.sleepQuality, equals(88.0));
    });

    test(
      '2. Platform wearable services sync through the health reader',
      () async {
        final healthConnect = HealthConnectWearableService(
          reader: PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Pixel Watch'),
            isIOS: false,
          ),
        );
        expect(healthConnect.providerName, equals('Google Health Connect'));
        final hcData = await healthConnect.syncHealthData();
        expect(hcData!.source, contains('Pixel Watch'));

        final healthKit = HealthKitWearableService(
          reader: PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Apple Watch'),
            isIOS: true,
          ),
        );
        expect(healthKit.providerName, equals('Apple HealthKit'));
        final hkData = await healthKit.syncHealthData();
        expect(hkData!.source, contains('Apple Watch'));
      },
    );

    test(
      '7. AI Coach Context Builder formats [HEALTH & RECOVERY CONTEXT] block',
      () {
        final builder = const CoachPromptBuilder();
        final now = DateTime.now();
        final context = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: now,
          todayHealthMetric: HealthMetric(
            timestamp: now,
            steps: 7200,
            sleepMinutes: 340, // 5h 40m
            heartRate: 74,
            restingHeartRate: 68,
            heartRateVariability: 48.0, // below average
            trainingLoad: 480.0, // High
          ),
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_1',
            lastUpdated: now,
            recoveryScore: 55,
            fatigueLevel: FatigueLevel.high,
            recommendation: RecoveryRecommendation.reduceIntensity,
            isDeloadRecommended: false,
          ),
        );

        final prompt = builder.buildPrompt(
          context: context,
          message: 'Should I do a heavy leg day today?',
        );

        expect(prompt, contains('[HEALTH & RECOVERY CONTEXT]'));
        expect(prompt, contains('Recovery Score: 55%'));
        expect(prompt, contains('HRV: 48 ms (below average)'));
        expect(prompt, contains('Avoid maximal strength training today'));
      },
    );

    test(
      '8. Mock AI Provider generates intelligent recovery and sleep drop coaching',
      () async {
        const ai = MockAIProvider();
        final now = DateTime.now();
        final context = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: now,
          todayHealthMetric: HealthMetric(
            timestamp: now,
            steps: 7200,
            sleepMinutes: 340,
          ),
        );

        final response = await ai.generateResponse(
          context: context,
          history: const [],
          message:
              'I only slept 5 hours and my recovery score dropped to 55%. Should I train hard today?',
        );

        expect(
          response,
          contains('You slept 5 hours and your recovery score dropped to 55%'),
        );
        expect(
          response,
          contains(
            'Previous heavy sessions after <6 hours sleep reduced your performance by 12%',
          ),
        );
      },
    );

    test(
      '9. WorkoutSession and WorkoutHistory persist before & after health metrics',
      () {
        final session = WorkoutSession(
          id: 'session_health_1',
          workoutId: 'w_1',
          workoutName: 'Leg Day',
          startTime: DateTime.now().subtract(const Duration(minutes: 50)),
          endTime: DateTime.now(),
          completedExercises: 5,
          totalVolume: 12500.0,
          caloriesBurned: 420.0,
          duration: const Duration(minutes: 50),
          readinessScore: 82.0,
          restingHR: 60,
          sleepQuality: 88.0,
          averageHR: 142,
          intensityScore: 85.0,
          recoveryImpact: 'Moderate fatigue',
        );

        final json = session.toJson();
        expect(json['readinessScore'], equals(82.0));
        expect(json['averageHR'], equals(142));

        final roundTrip = WorkoutSession.fromJson(json);
        expect(roundTrip.readinessScore, equals(82.0));
        expect(roundTrip.averageHR, equals(142));

        final history = session.toWorkoutHistory();
        expect(history.readinessScore, equals(82.0));
        expect(history.averageHR, equals(142));
      },
    );
  });
}
