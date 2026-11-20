import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:atlas/services/health/platform_health_reader.dart';
import '../mocks/fake_health_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/health_metrics.dart';
import 'package:atlas/models/health_metric_record.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/repositories/health_repository.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/recovery/recovery_prediction_engine.dart';
import 'package:atlas/services/wearables/health_connect_wearable_service.dart';
import 'package:atlas/services/wearables/health_kit_wearable_service.dart';
import 'package:atlas/services/wearables/wearable_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Wearable Integration & Health Data Ecosystem Tests (Phase E.1)', () {
    test(
      '1. HealthConnectWearableService handles permissions and data sync cleanly',
      () async {
        final service = HealthConnectWearableService(
          reader: PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Pixel Watch'),
            isIOS: false,
          ),
        );
        expect(await service.hasPermissions(), isFalse);
        expect(await service.isAvailable(), isTrue);

        final granted = await service.requestPermissions();
        expect(granted, isTrue);
        expect(await service.hasPermissions(), isTrue);

        final metrics = await service.syncHealthData(userId: 'athlete_01');
        expect(metrics, isNotNull);
        expect(metrics!.sourceDevice, equals('Pixel Watch'));
        expect(metrics.steps, equals(8432));
        expect(metrics.sleepHours, closeTo(7.0, 0.01));
        expect(metrics.restingHeartRate, equals(58.0));
        expect(metrics.heartRateVariability, equals(72.0));
      },
    );

    test(
      '2. HealthKitWearableService handles iOS permissions and availability',
      () async {
        final service = HealthKitWearableService(
          reader: PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(source: 'Apple Watch'),
            isIOS: true,
          ),
        );
        expect(await service.hasPermissions(), isFalse);
        expect(await service.isAvailable(), isTrue);

        final granted = await service.requestPermissions();
        expect(granted, isTrue);
        expect(await service.hasPermissions(), isTrue);

        final metrics = await service.syncHealthData(userId: 'athlete_ios');
        expect(metrics, isNotNull);
        expect(metrics!.sourceDevice, equals('Apple Watch'));
        expect(metrics.steps, equals(8432));
        expect(metrics.heartRateVariability, equals(72.0));
      },
    );

    test(
      '3. UniversalWearableManager supports runtime platform switching',
      () async {
        PlatformHealthReader.setInstance(
          PlatformHealthReader(
            FakeHealthDataSource.withTypicalDay(),
            isIOS: false,
          ),
        );
        addTearDown(PlatformHealthReader.resetInstance);
        final manager = UniversalWearableManager.instance;
        // The default is the device's own health store; there is no simulated platform.
        expect(manager.activePlatform, equals(WearablePlatform.googleFit));

        manager.setActivePlatform(WearablePlatform.googleFit);
        expect(manager.activePlatform, equals(WearablePlatform.googleFit));
        expect(
          manager.activeService.providerName,
          equals('Google Health Connect'),
        );

        final synced = await manager.syncActiveDevice(userId: 'test_user');
        expect(synced, isNotNull);
        expect(synced!.sourceDevice, equals('Test Watch'));

        manager.setActivePlatform(WearablePlatform.appleHealth);
        expect(manager.activePlatform, equals(WearablePlatform.appleHealth));
        expect(manager.activeService.providerName, equals('Apple HealthKit'));

        manager.setActivePlatform(WearablePlatform.googleFit);
      },
    );

    test(
      '4. Handles unavailable wearable service gracefully without exceptions',
      () async {
        final service = HealthConnectWearableService(
          reader: PlatformHealthReader(
            FakeHealthDataSource(available: false),
            isIOS: false,
          ),
        );

        expect(await service.isAvailable(), isFalse);
        expect(await service.requestPermissions(), isFalse);
        expect(await service.syncHealthData(), isNull);
      },
    );

    test(
      '5. HealthMetricRecord serialization and domain model conversion roundtrip',
      () {
        final record = HealthMetricRecord(
          id: 'metric_rec_123',
          userId: 'user_456',
          timestamp: DateTime(2026, 8, 27, 8, 30),
          heartRate: 72.0,
          restingHeartRate: 58.0,
          hrv: 68.0,
          sleepHours: 7.8,
          steps: 10500,
          caloriesBurned: 620.0,
          source: HealthMetricSource.healthConnect,
        );

        final json = record.toJson();
        expect(json['user_id'], equals('user_456'));
        expect(json['step_count'], equals(10500));
        expect(json['source'], equals('healthConnect'));

        final fromJson = HealthMetricRecord.fromJson(json);
        expect(fromJson.id, equals('metric_rec_123'));
        expect(fromJson.restingHeartRate, equals(58.0));
        expect(fromJson.hrv, equals(68.0));
        expect(fromJson.source, equals(HealthMetricSource.healthConnect));

        final domainMetrics = record.toHealthMetrics();
        expect(domainMetrics.sleepHours, equals(7.8));
        expect(domainMetrics.restingHeartRate, equals(58.0));
        expect(domainMetrics.heartRateVariability, equals(68.0));

        final convertedBack = HealthMetricRecord.fromHealthMetrics(
          domainMetrics,
        );
        expect(convertedBack.steps, equals(10500));
        expect(convertedBack.restingHeartRate, equals(58.0));
      },
    );

    test(
      '6. HealthRepository persists and retrieves HealthMetricRecord offline',
      () async {
        final repo = LocalHealthRepository();
        final record = HealthMetricRecord(
          id: 'metric_local_1',
          userId: 'usr_local',
          timestamp: DateTime.now(),
          heartRate: 70.0,
          restingHeartRate: 56.0,
          hrv: 74.0,
          sleepHours: 8.0,
          steps: 9500,
          caloriesBurned: 550.0,
          source: HealthMetricSource.appleHealth,
        );

        await repo.saveHealthRecord(record);

        final retrieved = await repo.getTodayHealthRecord();
        expect(retrieved, isNotNull);
        expect(retrieved!.steps, equals(9500));
        expect(retrieved.restingHeartRate, equals(56.0));
        expect(retrieved.hrv, equals(74.0));
        expect(retrieved.source, equals(HealthMetricSource.appleHealth));

        final history = await repo.getHealthRecordHistory();
        expect(history.length, greaterThanOrEqualTo(1));
      },
    );

    test(
      '7. RecoveryPredictionEngine calculates readiness with real physiological signals',
      () {
        final engine = const RecoveryPredictionEngine();
        final metricsOptimal = HealthMetrics(
          id: 'metric_optimal',
          userId: 'user_1',
          timestamp: DateTime.now(),
          sleepHours: 8.2,
          restingHeartRate: 52.0,
          heartRateVariability: 82.0,
          steps: 11000,
        );

        final reportOptimal = engine.analyzeReadiness(
          userId: 'user_1',
          workoutHistory: const [],
          healthMetrics: metricsOptimal,
        );

        expect(reportOptimal.readinessScore.score, greaterThanOrEqualTo(85.0));
        expect(reportOptimal.fatigueLevel, equals('low'));
        expect(reportOptimal.isDeloadRecommended, isFalse);

        final metricsFatigued = HealthMetrics(
          id: 'metric_fatigued',
          userId: 'user_1',
          timestamp: DateTime.now(),
          sleepHours: 4.5,
          restingHeartRate: 78.0,
          heartRateVariability: 32.0,
          steps: 3000,
        );

        final reportFatigued = engine.analyzeReadiness(
          userId: 'user_1',
          workoutHistory: [
            WorkoutHistory(
              workoutName: 'Heavy Legs',
              dateCompleted: DateTime.now().subtract(const Duration(hours: 12)),
              durationSeconds: 4500,
              exercisesCompleted: 6,
              completionPercentage: 100.0,
              totalVolume: 12000.0,
            ),
          ],
          healthMetrics: metricsFatigued,
        );

        expect(reportFatigued.readinessScore.score, lessThan(60.0));
        expect(reportFatigued.riskFactors, isNotEmpty);
        expect(
          reportFatigued.riskFactors.any(
            (r) =>
                r.contains('Elevated resting heart rate') ||
                r.contains('HRV') ||
                r.contains('sleep'),
          ),
          isTrue,
        );
      },
    );

    test(
      '8. CoachPromptBuilder injects formatted [HEALTH STATUS] into AI prompt',
      () {
        const builder = CoachPromptBuilder();
        final context = FitnessContext.initial().copyWith(
          userProfile: UserProfile(
            name: 'Alex',
            email: 'alex@Atlas.ai',
            phone: '',
            dob: '1995-01-01',
            gender: 'Male',
            height: '180',
            weight: '78',
            fitnessGoal: 'Hypertrophy',
            workoutExperience: 'Advanced',
            preferredDays: const ['Monday', 'Wednesday', 'Friday'],
            dietPreference: 'High Protein',
            massUnit: 'kg',
            lengthUnit: 'cm',
            subscription: 'Pro',
            privacy: 'public',
            notificationsEnabled: true,
            profilePic: '',
          ),
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_1',
            recoveryScore: 82,
            fatigueLevel: FatigueLevel.low,
            lastUpdated: DateTime.now(),
          ),
          todayHealthMetric: HealthMetric(
            timestamp: DateTime.now(),
            steps: 9200,
            sleepMinutes: 450, // 7h 30m
            restingHeartRate: 58,
            heartRateVariability: 65.0,
          ),
        );

        final prompt = builder.buildPrompt(
          message: "Should I train hard today?",
          context: context,
        );

        expect(prompt, contains('[HEALTH STATUS]'));
        expect(prompt, contains('Sleep: 7h 30m'));
        expect(prompt, contains('HRV: 65ms'));
        expect(prompt, contains('Resting HR: 58 bpm'));
        expect(prompt, contains('Recovery: 82%'));
      },
    );
  });
}
