import '../mocks/fake_step_sensor.dart';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_equipment_profile.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/workout_recommendation.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/goal_calculation_service.dart';
import 'package:atlas/services/workout_generator_engine.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/coach_notification_service.dart';
import 'package:atlas/services/achievement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    FitnessProvider.resetInstance();
  });

  group('Atlas End-to-End Integration & Reliability Suite (Phase 14)', () {
    test(
      '1. Complete User Journey: Onboarding -> Goal Setup -> Equipment Profile',
      () async {
        final provider = FitnessProvider.instance;

        // 1.1 Athlete Profile Setup
        final profile = UserProfile(
          name: 'Alexander Gymnast',
          email: 'alex@Atlas.app',
          phone: '+1234567890',
          dob: '1998-05-12',
          gender: 'Male',
          height: '180',
          weight: '78.5',
          fitnessGoal: 'Muscle Gain',
          workoutExperience: 'intermediate',
          preferredDays: ['Monday', 'Wednesday', 'Friday'],
          dietPreference: 'High Protein',
          massUnit: 'kg',
          lengthUnit: 'cm',
          subscription: 'Free',
          privacy: 'Public',
          notificationsEnabled: true,
          profilePic: '',
        );
        await provider.updateProfile(profile);
        expect(provider.profile.name, 'Alexander Gymnast');
        expect(provider.profile.weight, '78.5');

        // 1.2 Target Calculation & Goal Generation
        const goalService = GoalCalculationService();
        final userGoal = goalService.generateUserGoal(
          id: 'goal_integration_01',
          goalType: FitnessGoalType.muscleGain,
          fitnessLevel: FitnessLevel.intermediate,
          activityLevel: ActivityLevel.moderate,
          age: 26,
          height: 180,
          currentWeight: 78.5,
          targetWeight: 82.0,
        );

        expect(userGoal.targetCalories, greaterThan(2400));
        expect(userGoal.targetProtein, greaterThan(150));

        await provider.saveGoal(userGoal);
        expect(provider.currentGoal?.id, 'goal_integration_01');
        expect(provider.currentGoal?.goalType, FitnessGoalType.muscleGain);

        // 1.3 Physical Equipment Configuration
        final customEquipment = UserEquipmentProfile(
          userId: 'usr_local',
          availableEquipmentIds: [
            'barbell',
            'dumbbells',
            'bench',
            'pull_up_bar',
            'squat_rack',
          ],
          updatedAt: DateTime.now(),
        );
        await LocalStorage.saveUserEquipmentProfile(customEquipment);

        final loadedProfile = LocalStorage.getUserEquipmentProfile();
        expect(loadedProfile.availableEquipmentIds.length, 5);
        expect(loadedProfile.availableEquipmentIds.contains('barbell'), isTrue);
        expect(
          loadedProfile.availableEquipmentIds.contains('dumbbells'),
          isTrue,
        );
      },
    );

    test(
      '2. Workout Pipeline: Generation -> Execution -> Volume & PRs -> XP & Rank Progression',
      () async {
        final provider = FitnessProvider.instance;
        final eqProfile = LocalStorage.getUserEquipmentProfile();

        // 2.1 Dynamic Equipment-Aware Workout Generation
        final generator = WorkoutGeneratorEngine();
        final exercises = generator.generateExercisesForWorkout(
          workoutName: 'Upper Push Power & Chest Builder',
          focus: 'push',
          goal: 'hypertrophy',
          equipmentProfile: eqProfile,
          experienceLevel: 'intermediate',
        );

        expect(exercises.isNotEmpty, isTrue);
        for (final ex in exercises) {
          expect(ex['name'], isNotNull);
          expect(ex['sets'], isNotNull);
        }

        // 2.2 Structured Workout Session Construction
        final sessionStart = DateTime.now().subtract(
          const Duration(minutes: 50),
        );
        final sessionExercises = <WorkoutSessionExercise>[
          WorkoutSessionExercise(
            id: 'bench_press',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            isCompleted: true,
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 80.0,
                reps: 10,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 90.0,
                reps: 8,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 3,
                weight: 100.0,
                reps: 5,
                completed: true,
              ),
            ],
          ),
          WorkoutSessionExercise(
            id: 'incline_dumbbell_press',
            name: 'Incline Dumbbell Press',
            muscleGroup: 'Upper Chest',
            isCompleted: true,
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 30.0,
                reps: 10,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 32.0,
                reps: 8,
                completed: true,
              ),
            ],
          ),
        ];

        final totalVolume =
            (80 * 10 + 90 * 8 + 100 * 5) +
            (30 * 10 + 32 * 8); // 2020 + 556 = 2576 kg
        final session = WorkoutSession(
          id: 'session_int_01',
          workoutId: 'push_day_01',
          workoutName: 'Upper Push Power & Chest Builder',
          startTime: sessionStart,
          endTime: DateTime.now(),
          exercises: sessionExercises,
          completedExercises: 2,
          totalVolume: totalVolume.toDouble(),
          caloriesBurned: 380.0,
          duration: const Duration(minutes: 50),
          personalRecords: const ['100kg Bench Press (+5kg PR)'],
          xpEarned: 250,
        );

        final historyEntry = session.toWorkoutHistory();

        final initialXP = provider.userProgress.totalXP;
        final initialStreak = provider.userProgress.workoutStreak;

        // 2.3 Single Source of Truth Workout Completion Save
        final result = await provider.saveWorkoutCompletion(
          historyEntry,
          session: session,
        );

        expect(result.rewards.isNotEmpty, isTrue);
        expect(provider.userProgress.totalXP, greaterThan(initialXP));
        expect(
          provider.userProgress.workoutStreak,
          greaterThanOrEqualTo(initialStreak),
        );
        expect(provider.workoutHistory.isNotEmpty, isTrue);
        expect(
          provider.workoutHistory.first.workoutName,
          'Upper Push Power & Chest Builder',
        );

        // 2.4 Verify AI Fitness Memory Recorded Performance
        final events = FitnessMemory.instance.getEvents();
        expect(
          events.any((e) => e.target == 'Upper Push Power & Chest Builder'),
          isTrue,
        );
      },
    );

    test(
      '3. Nutrition Pipeline: Meal Logging -> Macro Progress -> XP Reward -> AI Context',
      () async {
        final provider = FitnessProvider.instance;
        final initialXP = provider.userProgress.totalXP;

        // 3.1 Log Food via FoodAnalysisResult (multimodal / barcode format)
        final scanResult = FoodAnalysisResult(
          foodName: 'Grilled Chicken Breast & Quinoa',
          confidence: 0.92,
          servingSize: 250.0,
          servingUnit: 'g',
          calories: 450.0,
          protein: 48.0,
          carbohydrates: 35.0,
          fats: 8.0,
          detectedIngredients: const ['Chicken Breast', 'Quinoa', 'Olive Oil'],
          timestamp: DateTime.now(),
        );

        await provider.logFoodAnalysisResult(scanResult, mealId: 'Lunch');

        // 3.2 Verify Nutrition State Updated Reactively
        final todayLog = provider.todayNutritionLog;
        expect(todayLog.dailyCalories, greaterThanOrEqualTo(450.0));
        expect(todayLog.dailyProtein, greaterThanOrEqualTo(48.0));
        expect(todayLog.calorieProgress, greaterThan(0.0));
        expect(todayLog.proteinProgress, greaterThan(0.0));

        // 3.3 Verify Meal Logging XP Award (+20 XP)
        expect(
          provider.userProgress.totalXP,
          greaterThanOrEqualTo(initialXP + 20),
        );

        // 3.4 Add Second Food Item via Manual/Search entry
        const proteinShake = FoodItem(
          id: 'food_whey_isolate',
          name: 'Whey Protein Isolate Shake',
          calories: 140,
          protein: 28,
          carbohydrates: 3,
          fats: 1,
          servingSize: '35g',
        );

        await provider.addFoodToMeal('Snacks', proteinShake, 35, 'g');
        expect(
          provider.todayNutritionLog.dailyProtein,
          greaterThanOrEqualTo(57.0),
        );
      },
    );

    test('4. AI Coach Context Integration & Intelligent Reasoning', () async {
      final provider = FitnessProvider.instance;

      // Set up activity, workout, and nutrition state
      // Steps come from the phone's step counter (here a test sensor).
      final stepSensor = FakeStepSensor();
      final counter = makeStepService(sensor: stepSensor);
      StepCounterService.setInstance(counter);
      addTearDown(StepCounterService.resetInstance);
      await counter.start();
      stepSensor.emit(1000);
      stepSensor.emit(9400);

      final ctx = provider.buildFitnessContext();
      expect(ctx.todaySteps, 8400);
      expect(ctx.todayStepsSource, 'phoneSensor');

      // 4.1 System Prompt Construction with Real Context
      const promptBuilder = CoachPromptBuilder();
      final systemPrompt = promptBuilder.buildPrompt(
        message: 'Should I train today?',
        context: ctx,
      );

      expect(systemPrompt.contains('[ATHLETE CONTEXT]'), isTrue);
      expect(systemPrompt.contains('[NUTRITION CONTEXT]'), isTrue);
      expect(systemPrompt.contains('[HEALTH & RECOVERY CONTEXT]'), isTrue);
      expect(systemPrompt.contains('8400'), isTrue); // Real steps in prompt

      // 4.2 AI Provider Query & Intelligent Reasoning
      const aiProvider = MockAIProvider();
      final response = await aiProvider.generateResponse(
        message: 'Should I train today?',
        context: ctx,
        history: const [],
      );

      expect(response.isNotEmpty, isTrue);
      expect(
        response.toLowerCase().contains('recovery') ||
            response.toLowerCase().contains('training') ||
            response.toLowerCase().contains('primed'),
        isTrue,
      );
    });

    test('5. Smart Notifications & Recovery Intelligence', () {
      final recovery = const RecoverySummary(
        recoveryScore: 82,
        sleepHours: 7.5,
        statusMessage: 'Ready for high intensity training',
      );

      final workoutRec = const WorkoutRecommendation(
        id: 'rec_push_01',
        workoutTitle: 'Upper Push Power',
        splitType: 'push',
        focusMuscles: ['Chest', 'Shoulders'],
        intensityLevel: 'High',
        isRestDay: false,
        recommendedExercises: ['Barbell Bench Press', 'Incline Dumbbell Press'],
      );

      final notifications = CoachNotificationService.instance
          .generateDailyNotifications(
            recovery: recovery,
            workout: workoutRec,
            todayNutrition: null,
          );

      expect(notifications.isNotEmpty, isTrue);
      expect(notifications.any((n) => n.category == 'workout'), isTrue);
      expect(notifications.first.body.contains('Upper Push Power'), isTrue);
    });

    test('6. Gamification Milestones & Achievement Unlocking', () {
      var progress = FitnessProvider.instance.userProgress;

      // Award high-volume session
      progress = progress.copyWith(
        completedWorkouts: 1,
        totalXP: 500,
        workoutStreak: 7,
      );

      final eval = AchievementService.evaluateAchievements(
        progress,
        hasNewPersonalRecord: true,
      );

      expect(eval.newlyUnlockedBadges.isNotEmpty, isTrue);
      expect(eval.updatedProgress.achievements.isNotEmpty, isTrue);
    });
  });
}
