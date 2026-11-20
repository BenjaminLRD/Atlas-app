import '../mocks/fake_step_sensor.dart';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/coach_memory.dart';
import 'package:atlas/services/health/health_service.dart';
import '../mocks/mock_health_service.dart';
import 'package:atlas/services/health/recovery_service.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/widgets/health/today_health_card.dart';
import 'package:atlas/screens/health_dashboard_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    HealthService.setInstance(MockHealthService());
  });

  tearDown(() {
    HealthService.resetInstance();
  });

  group('Health Data Architecture & Models (Phase 1 & 2)', () {
    test('HealthMetric serialization and helper formatters', () {
      final metric = HealthMetric(
        timestamp: DateTime(2026, 8, 16, 8, 30),
        steps: 8432,
        distanceKm: 5.2,
        activeCalories: 520.0,
        heartRate: 72,
        sleepMinutes: 440,
        restingHeartRate: 64,
        source: 'health_connect',
      );

      expect(metric.formattedSleep, '7h 20m');
      expect(metric.sleepHours, closeTo(7.33, 0.05));
      expect(metric.formattedDistance, '5.2 km');
      expect(metric.formattedCalories, '520 kcal');
      expect(metric.formattedHeartRate, '72 bpm');

      final json = metric.toJson();
      final reconstructed = HealthMetric.fromJson(json);

      expect(reconstructed.steps, 8432);
      expect(reconstructed.distanceKm, 5.2);
      expect(reconstructed.activeCalories, 520.0);
      expect(reconstructed.heartRate, 72);
      expect(reconstructed.sleepMinutes, 440);
      expect(reconstructed.restingHeartRate, 64);
      expect(reconstructed.source, 'health_connect');
    });

    test('MockHealthService test double integration', () async {
      final mock = MockHealthService();
      expect(await mock.hasPermissions(), isTrue);
      expect(await mock.requestPermissions(), isTrue);
      expect(await mock.isProviderAvailable(), isTrue);

      final today = await mock.getTodayHealthMetric();
      expect(today.steps, 8432);
      expect(today.heartRate, 72);

      final weekly = await mock.getWeeklyHealthHistory();
      expect(weekly.length, 7);
    });

    test('Real-time heart rate stream emits updates', () async {
      final mock = MockHealthService();
      final emissions = <int?>[];
      final sub = mock.watchHeartRate().listen(emissions.add);

      mock.emitHeartRate(75);
      mock.emitHeartRate(128);
      mock.emitHeartRate(82);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emissions, [75, 128, 82]);
      await sub.cancel();
    });
  });

  group('Recovery Score Engine (Phase 5 - 40/30/20/10)', () {
    test(
      'Calculates high readiness score for optimal sleep and moderate training',
      () {
        final breakdown = RecoveryService.instance.calculateRecovery(
          sleepMinutes: 480, // 8h -> 40.0 pts
          consecutiveTrainingDays: 2, // -> 30.0 pts
          stepsToday: 8500, // -> 20.0 pts
          restDaysLast7Days: 2, // -> 10.0 pts
        );

        expect(breakdown.totalScore, 100);
        expect(breakdown.sleepComponent, 40.0);
        expect(breakdown.trainingComponent, 30.0);
        expect(breakdown.activityComponent, 20.0);
        expect(breakdown.restDaysComponent, 10.0);
        expect(breakdown.statusEmoji, '🔥');
        expect(breakdown.statusText, 'Ready for heavy training');
        expect(breakdown.shouldReduceVolume, isFalse);
      },
    );

    test(
      'Calculates lower readiness and recommends volume reduction on sleep deficit and high fatigue',
      () {
        final breakdown = RecoveryService.instance.calculateRecovery(
          sleepMinutes: 300, // 5h sleep deficit
          consecutiveTrainingDays: 5, // 5 days heavy training
          stepsToday: 3000,
          restDaysLast7Days: 0,
          recentVolumeSurgePercent: 30.0,
        );

        expect(breakdown.totalScore, lessThan(60));
        expect(breakdown.shouldReduceVolume, isTrue);
        expect(breakdown.recommendation, contains('fatigue'));
      },
    );
  });

  group('AI Coach Health Context & Fatigue Intent (Phase 4)', () {
    test(
      'CoachPromptBuilder includes health telemetry and sleep directives',
      () {
        final context = FitnessContext.initial().copyWith(
          todayHealthMetric: HealthMetric(
            timestamp: DateTime.now(),
            steps: 9200,
            sleepMinutes: 440,
            heartRate: 74,
            activeCalories: 560.0,
          ),
        );

        final prompt = const CoachPromptBuilder().buildPrompt(
          message: 'Why am I tired during workouts?',
          context: context,
          memory: const CoachMemory(),
        );

        expect(
          prompt,
          contains(
            'Health & Sleep Telemetry: 7h 20m sleep (7.3 hrs), 74 bpm HR',
          ),
        );
        expect(prompt, contains('When the athlete asks why they are tired'));
      },
    );

    test(
      'MockAIProvider handles fatigue query with volume surge and sleep reduction diagnosis',
      () async {
        final provider = const MockAIProvider();
        final context = FitnessContext.initial().copyWith(
          todayHealthMetric: HealthMetric(
            timestamp: DateTime.now(),
            steps: 8432,
            sleepMinutes: 348, // 5.8 hrs
          ),
        );

        final response = await provider.generateResponse(
          message: 'Why am I tired during workouts?',
          context: context,
          history: const [],
        );

        expect(response, contains('Your training volume increased 30%'));
        expect(response, contains('7.5h → 5.8h'));
        expect(response, contains('Reduce intensity today'));
      },
    );
  });

  group('Responsive Widget Tests Across Viewports (Phase 9)', () {
    final viewports = [
      const Size(320, 640),
      const Size(360, 740),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'TodayHealthCard renders with zero overflow on ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          // The card shows the step counter's daily total (here a test sensor).
          final stepSensor = FakeStepSensor();
          final counter = makeStepService(sensor: stepSensor);
          StepCounterService.setInstance(counter);
          addTearDown(StepCounterService.resetInstance);
          await counter.start();
          stepSensor.emit(100);
          stepSensor.emit(8532);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TodayHealthCard(
                    initialMetric: HealthMetric(
                      timestamp: DateTime(2026, 8, 16),
                      steps: 8432,
                      activeCalories: 520.0,
                      heartRate: 72,
                      sleepMinutes: 440,
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text("Today's Health"), findsOneWidget);
          expect(find.text('8432'), findsOneWidget);
          expect(find.text('520'), findsOneWidget);
          expect(find.text('72'), findsOneWidget);
          expect(find.text('7h 20m'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'HealthDashboardScreen renders with zero overflow on ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: const HealthDashboardScreen(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Health & Wearables'), findsOneWidget);
          expect(find.text('SLEEP & RECOVERY'), findsOneWidget);
          expect(find.text('TODAY'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
