import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/screens/cardio_activity_screen.dart';
import 'package:atlas/screens/cardio_session_screen.dart';
import 'package:atlas/services/activity_score_service.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/fake_step_sensor.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:atlas/services/step_tracking_service.dart';
import 'package:atlas/widgets/activity/today_activity_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Phase 1 & 2: Cardio & Activity Models', () {
    test('Exercise model supports ExerciseType and cardio metadata', () {
      const ex = Exercise(
        id: 'treadmill_run',
        name: 'Treadmill Run',
        muscleGroup: 'Cardiovascular',
        equipment: 'Treadmill',
        type: ExerciseType.cardio,
        metValue: 9.8,
        cardioCategory: 'Running',
        recommendedDuration: 25,
        estimatedCaloriesPerMinute: 12.0,
      );

      expect(ex.type, ExerciseType.cardio);
      expect(ex.metValue, 9.8);
      expect(ex.cardioCategory, 'Running');
      expect(ex.recommendedDuration, 25);
      expect(ex.estimatedCaloriesPerMinute, 12.0);

      final json = ex.toJson();
      final fromJson = Exercise.fromJson(json);
      expect(fromJson.type, ExerciseType.cardio);
      expect(fromJson.metValue, 9.8);
      expect(fromJson.cardioCategory, 'Running');
    });

    test('Exercise.defaultRegistry contains cardio catalog', () {
      final all = Exercise.defaultRegistry();
      final cardioList = all
          .where((e) => e.type == ExerciseType.cardio)
          .toList();

      expect(cardioList.length, greaterThanOrEqualTo(16));
      expect(cardioList.any((e) => e.name == 'Treadmill Run'), isTrue);
      expect(cardioList.any((e) => e.name == 'Stationary Bike'), isTrue);
      expect(cardioList.any((e) => e.name == 'Rowing Machine'), isTrue);
      expect(cardioList.any((e) => e.name == 'Jump Rope'), isTrue);
    });

    test('ActivityRecord serialization and todaySample', () {
      final sample = ActivityRecord.todaySample(
        steps: 8400,
        activeMinutes: 65,
        caloriesBurned: 480.0,
        distanceKm: 6.1,
      );
      expect(sample.steps, 8400);
      expect(sample.activeMinutes, 65);
      expect(sample.type, ActivityType.steps);

      final json = sample.toJson();
      final deserialized = ActivityRecord.fromJson(json);
      expect(deserialized.steps, 8400);
      expect(deserialized.activeMinutes, 65);
      expect(deserialized.caloriesBurned, 480.0);
      expect(deserialized.distanceKm, 6.1);
    });

    test('CardioSession calculations and formattedDuration', () {
      final session = CardioSession(
        id: 'session_1',
        exerciseId: 'outdoor_run',
        exerciseName: 'Outdoor Run',
        category: 'Running',
        durationSeconds: 1530, // 25 min 30 sec
        distanceKm: 3.5,
        caloriesBurned: 280.0,
        startTime: DateTime.now().subtract(const Duration(minutes: 26)),
        endTime: DateTime.now(),
        metValue: 9.5,
      );

      expect(session.formattedDuration, '25:30');
      expect(session.paceMinutesPerKm, contains('/km'));
      expect(session.caloriesPerMinute, greaterThan(10.0));

      final json = session.toJson();
      final parsed = CardioSession.fromJson(json);
      expect(parsed.exerciseName, 'Outdoor Run');
      expect(parsed.durationSeconds, 1530);
      expect(parsed.distanceKm, 3.5);
    });
  });

  group('Phase 3 & 5: Step Tracking & Activity Score Services', () {
    test('StepTrackingService goal, estimates and the shared daily total', () async {
      const stepService = StepTrackingService();

      expect(stepService.getStepGoal(), 10000);
      await stepService.setStepGoal(8500);
      expect(stepService.getStepGoal(), 8500);

      // Estimates are calculated from real steps; no steps means no estimate.
      expect(StepTrackingService.caloriesFor(null), isNull);
      expect(StepTrackingService.distanceKmFor(null), isNull);
      expect(
        StepTrackingService.caloriesFor(10000, userWeightKg: 70.0),
        closeTo(420.0, 50.0),
      );
      // 10,000 steps * 0.762 m = 7.62 km
      expect(StepTrackingService.distanceKmFor(10000), 7.62);

      // Steps cannot be typed in: the total comes from the step counter only.
      final sensor = FakeStepSensor();
      final counter = makeStepService(sensor: sensor);
      StepCounterService.setInstance(counter);
      addTearDown(StepCounterService.resetInstance);
      expect(stepService.today.steps, isNull);
      await counter.start();
      sensor.emit(100);
      sensor.emit(9300);
      expect(stepService.today.steps, 9200);

      // The weekly list has 7 days; only today has a reading.
      final weekly = stepService.week;
      expect(weekly.length, 7);
      expect(weekly.last.steps, 9200);
      expect(weekly.take(6).every((d) => d.steps == null), isTrue);
    });

    test('ActivityScoreResult leaves the steps part out when steps are unknown', () {
      final unknown = ActivityScoreResult.calculate(
        steps: null,
        stepGoal: 10000,
        isWorkoutCompleted: true,
        workoutMinutes: 45,
        cardioMinutes: 20,
      );
      expect(unknown.stepsKnown, isFalse);
      expect(unknown.totalScore, 100); // 60 of 60 known points, not 60 of 100
      final zero = ActivityScoreResult.calculate(
        steps: 0,
        stepGoal: 10000,
        isWorkoutCompleted: true,
        workoutMinutes: 45,
        cardioMinutes: 20,
      );
      expect(zero.stepsKnown, isTrue);
      expect(zero.totalScore, 60); // zero steps really is zero
    });

    test('ActivityScoreService computes weighted composite score accurately', () {
      // 1. Excellent scenario: 100% steps (40 pts) + Completed Workout (40 pts) + 20 min cardio (20 pts) = 100 pts
      final score100 = ActivityScoreResult.calculate(
        steps: 10000,
        stepGoal: 10000,
        isWorkoutCompleted: true,
        workoutMinutes: 45,
        cardioMinutes: 20,
      );
      expect(score100.totalScore, 100);
      expect(score100.stepsScore, 40.0);
      expect(score100.workoutScore, 40.0);
      expect(score100.cardioScore, 20.0);
      expect(score100.rating, 'Excellent');

      // 2. Partial scenario: 5,000 / 10,000 steps (20 pts) + No workout (0 pts) + 10 min cardio (10 pts) = 30 pts
      final score30 = ActivityScoreResult.calculate(
        steps: 5000,
        stepGoal: 10000,
        isWorkoutCompleted: false,
        workoutMinutes: 0,
        cardioMinutes: 10,
      );
      expect(score30.totalScore, 30);
      expect(score30.stepsScore, 20.0);
      expect(score30.rating, 'Keep Moving');

      // 3. Great scenario: 8,000 steps (32 pts) + 30 min workout (26.7 pts) + 15 min cardio (15 pts) = 74 pts
      final scoreGreat = ActivityScoreResult.calculate(
        steps: 8000,
        stepGoal: 10000,
        isWorkoutCompleted: false,
        workoutMinutes: 30,
        cardioMinutes: 15,
      );
      expect(scoreGreat.totalScore, greaterThanOrEqualTo(70));
      expect(scoreGreat.rating, 'Great');
    });
  });

  group('Phase 7: AI Coach Activity & Fat Loss Plateau Integration', () {
    test(
      'CoachPromptBuilder includes steps, activity score, and cardio context',
      () {
        const builder = CoachPromptBuilder();
        final ctx = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          todayActivity: ActivityRecord(
            id: 'act_1',
            date: DateTime(2026, 1, 1),
            activeMinutes: 62,
            caloriesBurned: 460.0,
          ),
          todaySteps: 8200,
          stepGoal: 10000,
          activityScore: 84,
          recentCardio: [
            CardioSession(
              id: 'c1',
              exerciseId: 'rowing_machine',
              exerciseName: 'Rowing Machine',
              category: 'Rowing',
              durationSeconds: 1200,
              caloriesBurned: 210,
              startTime: DateTime.now(),
            ),
          ],
          generatedAt: DateTime.now(),
        );

        final prompt = builder.buildPrompt(
          message: 'How is my daily activity tracking?',
          context: ctx,
        );

        expect(prompt, contains('8200 / 10000 steps'));
        expect(prompt, contains('Activity Score: 84/100'));
        expect(prompt, contains('Rowing Machine'));
        expect(prompt, contains('COACHING DIRECTIVES'));
      },
    );

    test('MockAIProvider handles plateau and step drop queries', () async {
      final ai = MockAIProvider();
      final ctx = FitnessContext(
        nutritionSummary: NutritionSummary.empty(),
        progressSummary: ProgressSummary.zero(),
        userProgress: UserProgress.initial(),
        nutritionProgress: NutritionProgress.initial(),
        todayActivity: ActivityRecord(
          id: 'act_1',
          date: DateTime(2026, 1, 1),
          steps: 4200,
          activeMinutes: 28,
        ),
        stepGoal: 10000,
        activityScore: 52,
        generatedAt: DateTime.now(),
      );

      final response = await ai.generateResponse(
        message: 'Why am I not losing fat? I feel stuck at a plateau.',
        context: ctx,
        history: [],
      );

      expect(response, contains('Movement Drop'));
      expect(response, contains('4200 / 10000 steps/day'));
      expect(response, contains('20-minute brisk walk'));
      expect(response, contains('Cardio & Activity Hub'));
    });
  });

  group(
    'Phase 4, 6 & Responsive UI Viewport Tests (320px, 360px, 390px, 412px)',
    () {
      const viewports = [
        Size(320, 700), // Smallest Android / iPhone SE
        Size(360, 800), // Standard Android
        Size(390, 844), // iPhone 13/14/15
        Size(412, 915), // Pixel / Flagship
      ];

      testWidgets(
        'TodayActivityCard renders without overflow across viewports',
        (tester) async {
          for (final size in viewports) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TodayActivityCard(
                      isWorkoutCompleted: true,
                      workoutMinutes: 45,
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text("Today's Activity"), findsOneWidget);
            expect(find.text('WORKOUT'), findsOneWidget);
            expect(find.text('CALORIES (EST.)'), findsOneWidget);
            expect(find.text('CARDIO TODAY'), findsOneWidget);
            expect(find.text('--'), findsWidgets); // no step reading: dashes
          }
        },
      );

      testWidgets(
        'CardioSessionScreen renders without overflow across viewports',
        (tester) async {
          const exercise = Exercise(
            id: 'treadmill_run',
            name: 'Treadmill Run',
            muscleGroup: 'Cardiovascular',
            equipment: 'Treadmill',
            type: ExerciseType.cardio,
            metValue: 9.8,
            cardioCategory: 'Running',
          );

          for (final size in viewports) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            await tester.pumpWidget(
              const MaterialApp(home: CardioSessionScreen(exercise: exercise)),
            );

            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            expect(find.text('SESSION DURATION'), findsOneWidget);
            expect(find.text('CALORIES'), findsOneWidget);
            expect(find.text('DISTANCE'), findsOneWidget);
            expect(find.text('Finish Session'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'CardioActivityScreen renders and filters categories without overflow across viewports',
        (tester) async {
          for (final size in viewports) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            await tester.pumpWidget(
              const MaterialApp(home: CardioActivityScreen()),
            );

            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('CARDIO & ACTIVITY'), findsOneWidget);
            expect(find.text('DAILY ACTIVITY SCORE'), findsOneWidget);
            expect(find.text("TODAY'S MOVEMENT"), findsOneWidget);
            expect(find.text('START CARDIO WORKOUT'), findsOneWidget);

            // Tap category chip
            await tester.tap(find.text('Running').first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    },
  );
}
