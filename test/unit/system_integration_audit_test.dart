import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/workout_generator_engine.dart';
import 'package:atlas/services/workout_streak_service.dart';
import 'package:atlas/widgets/common/app_empty_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessMemory.resetInstance();
  });

  group('Phase D.1 — Production Readiness & System Integration Audit', () {
    // =========================================================================
    // 1. WORKOUT GENERATION & EXECUTION PIPELINE AUDIT
    // =========================================================================
    test(
      'Flow 1: End-to-End Workout Generation, Set Tracking, and History Execution',
      () async {
        final engine = WorkoutGeneratorEngine();

        // 1.1 Generate dynamic workout for Push Day
        final exercises = engine.generateExercisesForWorkout(
          workoutName: 'Push Day Hypertrophy',
          focus: 'chest_shoulders_triceps',
          goal: 'build_muscle',
          durationMinutes: 45,
        );

        expect(exercises, isNotEmpty);
        expect(exercises.length, inInclusiveRange(3, 8));

        // 1.2 Simulate workout set tracking and completion
        final List<WorkoutSessionExercise> sessionExercises = [];
        double totalSimulatedVolume = 0.0;
        int totalCompletedSets = 0;

        for (int i = 0; i < exercises.length; i++) {
          final exMap = exercises[i];
          final setsList = exMap['sets'] as List;
          final List<WorkoutSessionSet> completedSets = [];

          for (int s = 0; s < setsList.length; s++) {
            const double weight = 70.0;
            const int reps = 10;
            totalSimulatedVolume += (weight * reps);
            totalCompletedSets++;

            completedSets.add(
              WorkoutSessionSet(
                setNumber: s + 1,
                weight: weight,
                reps: reps,
                completed: true,
                rpe: 8.0,
              ),
            );
          }

          sessionExercises.add(
            WorkoutSessionExercise(
              id: 'ex_$i',
              name: exMap['name'] as String,
              muscleGroup: exMap['primaryTarget'] as String? ?? 'Chest',
              sets: completedSets,
              isCompleted: true,
            ),
          );
        }

        // 1.3 Construct structured WorkoutSession
        final session = WorkoutSession(
          id: 'session_audit_001',
          workoutId: 'push_day_01',
          workoutName: 'Push Day Hypertrophy',
          startTime: DateTime.now().subtract(const Duration(minutes: 45)),
          endTime: DateTime.now(),
          exercises: sessionExercises,
          completedExercises: sessionExercises.length,
          totalVolume: totalSimulatedVolume,
          caloriesBurned: 320.0,
          duration: const Duration(minutes: 45),
          state: WorkoutSessionState.completed,
          personalRecords: const ['Bench Press +5kg PR'],
          xpEarned: 250,
        );

        expect(session.totalVolume, equals(totalSimulatedVolume));
        expect(totalCompletedSets, greaterThan(0));
        expect(session.isFullyCompleted, isTrue);

        // 1.4 Convert to WorkoutHistory and persist to system
        final history = session.toWorkoutHistory();
        expect(history.workoutName, equals('Push Day Hypertrophy'));
        expect(history.totalVolume, equals(totalSimulatedVolume));

        // 1.5 Verify Streak calculation from real workout history
        const streakService = WorkoutStreakService();
        final streakData = streakService.calculateStreak([history]);
        expect(streakData.currentStreak, equals(1));
        expect(streakData.longestStreak, equals(1));
        expect(streakData.lastWorkoutDate, isNotNull);

        // 1.6 Verify AI Fitness Memory records performance
        await FitnessMemory.instance.recordWorkoutExecution(
          workoutTitle: history.workoutName,
          totalVolume: history.totalVolume,
          completedSets: history.totalSets,
          prs: history.personalRecords,
          exercises: session.exercises,
        );

        final events = FitnessMemory.instance.getEvents();
        expect(events, isNotEmpty);
      },
    );

    // =========================================================================
    // 2. NUTRITION PIPELINE & FOOD SCANNER AUDIT
    // =========================================================================
    test(
      'Flow 2: OpenFoodFacts Barcode Lookup and Nutrition Parsing',
      () async {
        // Mock OpenFoodFacts REST API response
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('3017620422003')) {
            final jsonResponse = {
              'status': 1,
              'product': {
                '_id': '3017620422003',
                'product_name': 'Nutella Hazelnut Spread',
                'brands': 'Ferrero',
                'serving_size': '30 g',
                'nutriments': {
                  'energy-kcal_100g': 539,
                  'proteins_100g': 6.3,
                  'carbohydrates_100g': 57.5,
                  'fat_100g': 30.9,
                },
                'ingredients_text':
                    'Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%), emulsifier: lecithins (soya), vanillin',
              },
            };
            return http.Response(jsonEncode(jsonResponse), 200);
          }
          return http.Response(jsonEncode({'status': 0}), 404);
        });

        final service = OpenFoodFactsService(httpClient: mockClient);

        // 2.1 Query valid barcode
        final food = await service.getProductByBarcode('3017620422003');
        expect(food, isNotNull);
        expect(food!.name, contains('Nutella'));
        expect(food.calories, greaterThan(500));
        expect(food.protein, greaterThan(5));
        expect(food.carbohydrates, greaterThan(50));
        expect(food.fats, greaterThan(30));

        // 2.2 Query non-existent barcode handles gracefully
        final missing = await service.getProductByBarcode('0000000000000');
        expect(missing, isNull);
      },
    );

    test(
      'Flow 2.2: Food AI Vision Analysis Data Conversion',
      () async {
        final analysis = FoodAnalysisResult(
          foodName: 'Grilled Chicken Salad',
          servingSize: 350,
          servingUnit: 'g',
          calories: 420,
          protein: 45.0,
          carbohydrates: 12.0,
          fats: 14.0,
          detectedIngredients: const [
            'Chicken Breast',
            'Romaine Lettuce',
            'Olive Oil',
            'Cherry Tomatoes',
          ],
          confidence: 0.92,
          notes: 'High protein meal, low carb salad',
          timestamp: DateTime.now(),
        );

        final foodItem = analysis.toFoodItem(customId: 'food_test_001');

        expect(foodItem.name, equals('Grilled Chicken Salad'));
        expect(foodItem.servingSize, equals('350g'));
        expect(foodItem.calories, equals(120.0));
        expect(foodItem.protein, closeTo(12.85, 0.1));
      },
    );

    // =========================================================================
    // 3. AI COACH MULTI-DOMAIN CONTEXT INJECTION AUDIT
    // =========================================================================
    test(
      'Flow 3: Coach Prompt Builder Compiles Multi-Domain Context',
      () {
        const builder = CoachPromptBuilder();

        final context = FitnessContext.initial().copyWith(
          userProfile: UserProfile.defaultProfile().copyWith(
            name: 'Athlete John',
            fitnessGoal: 'Hypertrophy and Strength',
            workoutExperience: 'Advanced',
          ),
          workoutHistory: [
            WorkoutHistory(
              workoutName: 'Heavy Bench Protocol',
              dateCompleted: DateTime.now().subtract(const Duration(days: 1)),
              durationSeconds: 3000,
              exercisesCompleted: 5,
              completionPercentage: 100.0,
              caloriesBurned: 350,
              totalVolume: 8200,
              totalSets: 16,
              personalRecords: const ['Bench 110kg x 5'],
            ),
          ],
          todayNutritionLog: NutritionLog(
            id: 'log_01',
            date: DateTime.now(),
            calorieGoal: 2800,
            proteinGoal: 180,
            carbohydrateGoal: 300,
            fatGoal: 80,
            meals: [
              MealEntry(
                id: 'meal_01',
                name: 'Pre-workout Meal',
                foods: const [
                  FoodItem(
                    id: 'f_01',
                    name: 'Chicken Rice Bowl',
                    calories: 2100,
                    protein: 160,
                    carbohydrates: 220,
                    fats: 65,
                  ),
                ],
                completed: true,
              ),
            ],
          ),
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_01',
            recoveryScore: 88,
            fatigueLevel: FatigueLevel.low,
            lastUpdated: DateTime.now(),
          ),
          todayHealthMetric: HealthMetric(
            timestamp: DateTime.now(),
            steps: 8500,
            activeCalories: 450,
            heartRate: 64,
            restingHeartRate: 58,
            sleepMinutes: 468,
          ),
          userProgress: UserProgress.initial().copyWith(
            workoutStreak: 5,
            longestStreak: 12,
            completedWorkouts: 42,
            totalXP: 14500,
            rankedUnlocked: true,
            currentRank: 'Gold',
            currentDivision: 'Division I',
          ),
        );

        final prompt = builder.buildPrompt(
          message: 'What workout should I do today?',
          context: context,
        );

        // Verify context injection across all domains
        expect(prompt, contains('Hypertrophy and Strength'));
        expect(prompt, contains('Heavy Bench Protocol'));
        expect(prompt, contains('2100'));
        expect(prompt, contains('2800'));
        expect(prompt, contains('160'));
        expect(prompt, contains('88'));
      },
    );

    // =========================================================================
    // 4. STANDARDIZED EMPTY STATE STRINGS AUDIT
    // =========================================================================
    testWidgets(
      'Flow 4: Verification of Standardized Empty State Titles & Subtitles',
      (tester) async {
        // 4.1 No workouts empty state
        final noWorkouts = AppEmptyState.noWorkouts(
          onStartWorkout: () {},
        );
        expect(noWorkouts.title, equals('No completed workouts yet.'));
        expect(
          noWorkouts.subtitle,
          equals(
            'Complete your first workout to start your streak and unlock performance analytics.',
          ),
        );

        // 4.2 No nutrition empty state
        final noNutrition = AppEmptyState.noNutrition();
        expect(noNutrition.title, equals('No meals tracked today.'));
        expect(
          noNutrition.subtitle,
          equals(
            'Log your first meal today to track calories and macronutrients.',
          ),
        );

        // 4.3 No progress empty state
        final noProgress = AppEmptyState.noProgress();
        expect(
          noProgress.title,
          equals('Complete workouts to see your progress.'),
        );
        expect(
          noProgress.subtitle,
          equals(
            'Your strength curves, volume charts, and personal records will appear after your first session.',
          ),
        );

        // 4.4 No chat / coach empty state
        final noChat = AppEmptyState.noChat();
        expect(noChat.title, equals('Start chatting with your coach.'));
        expect(
          noChat.subtitle,
          equals(
            'Ask your AI coach for personalized workouts, nutrition plans, and form advice.',
          ),
        );

        // 4.5 Render empty state widget cleanly without overflow
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: noWorkouts,
              ),
            ),
          ),
        );

        expect(find.text('No completed workouts yet.'), findsOneWidget);
        expect(find.text('Start Workout'), findsOneWidget);
      },
    );

    // =========================================================================
    // 5. LOCAL STORAGE CLEAN DEFAULT INITIALIZATION AUDIT
    // =========================================================================
    test(
      'Flow 5: Fresh User Defaults in LocalStorage are Clean and Un-faked',
      () {
        // Following list must default to empty list for fresh user
        final following = LocalStorage.getFollowingUserIds();
        expect(following, isEmpty);

        // Default notifications must not contain fake workout reminders
        final notifications = LocalStorage.getNotificationModels();
        expect(notifications, isNotEmpty);
        for (final n in notifications) {
          expect(n.body, isNot(contains('140g today')));
          expect(n.body, isNot(contains('Wednesday leg workout')));
        }
      },
    );
  });
}
