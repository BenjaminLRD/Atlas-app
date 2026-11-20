import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/progressive_overload_service.dart';
import 'package:atlas/services/rest_timer_service.dart';
import 'package:atlas/services/workout_execution_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    await FitnessMemory.instance.clearMemory();
    ProgressiveOverloadService.resetInstance();
    RestTimerService.resetInstance();

    final profile = UserProfile(
      name: 'Marcus Vance',
      email: 'marcus@example.com',
      phone: '+1 555-019-9988',
      dob: '1994-06-20',
      gender: 'Male',
      height: '182',
      weight: '82.0',
      fitnessGoal: 'Hypertrophy',
      workoutExperience: 'advanced',
      preferredDays: ['Monday', 'Wednesday', 'Friday'],
      dietPreference: 'High Protein',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Pro',
      privacy: 'Public',
      notificationsEnabled: true,
      profilePic: '',
    );

    final goal = UserGoal(
      id: 'goal_exec_01',
      goalType: FitnessGoalType.muscleGain,
      fitnessLevel: FitnessLevel.advanced,
      activityLevel: ActivityLevel.veryActive,
      age: 30,
      height: 182.0,
      currentWeight: 82.0,
      targetWeight: 85.0,
      targetCalories: 2800.0,
      targetProtein: 175.0,
      targetCarbohydrates: 340.0,
      targetFats: 75.0,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final provider = FitnessProvider.instance;
    await provider.updateProfile(profile);
    await provider.saveGoal(goal);
  });

  group('Atlas Real Workout Execution Engine (Phase B.1)', () {
    test('1. Workout Session Creation, Set Tracking & Volume Calculation', () {
      final now = DateTime.now();

      final set1 = WorkoutSessionSet(
        setNumber: 1,
        weight: 80.0,
        reps: 10,
        completed: true,
        rpe: 8.0,
        completedAt: now.subtract(const Duration(minutes: 10)),
      );
      final set2 = WorkoutSessionSet(
        setNumber: 2,
        weight: 80.0,
        reps: 10,
        completed: true,
        rpe: 8.5,
        completedAt: now.subtract(const Duration(minutes: 7)),
      );
      final set3 = WorkoutSessionSet(
        setNumber: 3,
        weight: 85.0,
        reps: 8,
        completed: true,
        rpe: 9.0,
        completedAt: now.subtract(const Duration(minutes: 4)),
      );
      final set4 = const WorkoutSessionSet(
        setNumber: 4,
        weight: 85.0,
        reps: 8,
        completed: false,
      );

      final exercise = WorkoutSessionExercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sets: [set1, set2, set3, set4],
        isCompleted: false,
      );

      // Volume: (80*10) + (80*10) + (85*8) = 800 + 800 + 680 = 2280 kg
      expect(exercise.totalVolume, equals(2280.0));
      expect(exercise.maxWeight, equals(85.0));
      expect(exercise.completedSetsCount, equals(3));
      expect(exercise.totalSetsCount, equals(4));
      expect(exercise.totalCompletedReps, equals(28));

      final session = WorkoutSession(
        id: 'sess_push_01',
        workoutId: 'push_hypertrophy_01',
        workoutName: 'Upper Push Power',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now,
        exercises: [exercise],
        completedExercises: 1,
        totalVolume: exercise.totalVolume,
        caloriesBurned: 240.0,
        duration: const Duration(minutes: 30),
      );

      expect(session.calculatedTotalVolume, equals(2280.0));
      expect(session.completedSetsCount, equals(3));
      expect(session.totalSetsCount, equals(4));
      expect(session.completionPercentage, equals(75.0));
      expect(session.durationSeconds, equals(1800));
    });

    test('2. Estimated 1RM & Energy Expenditure Calculations', () {
      final overloadService = ProgressiveOverloadService.instance;

      // Epley Formula: 1RM = Weight * (1 + Reps/30)
      // 100kg x 1 rep = 100.0 kg
      expect(overloadService.calculateEstimated1RM(100.0, 1), equals(100.0));

      // 100kg x 5 reps = 100 * (1 + 5/30) = 116.666... kg
      final est1RM5 = overloadService.calculateEstimated1RM(100.0, 5);
      expect(est1RM5, closeTo(116.67, 0.05));

      // 80kg x 10 reps = 80 * (1 + 10/30) = 106.666... kg
      final est1RM10 = overloadService.calculateEstimated1RM(80.0, 10);
      expect(est1RM10, closeTo(106.67, 0.05));

      // Calorie expenditure computation (duration + mechanical volume)
      final calories = overloadService.calculateCaloriesBurned(
        durationSeconds: 2700, // 45 mins
        totalVolumeKg: 8500,
        completedSets: 16,
        athleteWeightKg: 80.0,
      );

      expect(calories, greaterThan(250.0));
      expect(calories, lessThan(600.0));
    });

    test(
      '3. Personal Record (PR) Detection & Progression Evaluation',
      () async {
        final overloadService = ProgressiveOverloadService.instance;

        // 3.1 Baseline Workout (Should NOT create fake PR on day 1)
        final baselineSets = [
          const WorkoutSessionSet(
            setNumber: 1,
            weight: 80.0,
            reps: 8,
            completed: true,
          ),
          const WorkoutSessionSet(
            setNumber: 2,
            weight: 80.0,
            reps: 8,
            completed: true,
          ),
        ];
        final baselineEx = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          sets: baselineSets,
          isCompleted: true,
        );
        final baselineSession = WorkoutSession(
          id: 'session_01',
          workoutId: 'push_01',
          workoutName: 'Push Day',
          startTime: DateTime.now().subtract(const Duration(days: 7)),
          endTime: DateTime.now().subtract(const Duration(days: 7)),
          exercises: [baselineEx],
          completedExercises: 1,
          totalVolume: 1280.0,
          caloriesBurned: 150.0,
          duration: const Duration(minutes: 30),
        );

        final baselinePRs = overloadService.evaluatePersonalRecords(
          exercises: [baselineEx],
          workoutId: 'push_01',
          pastSessions: [],
        );
        expect(baselinePRs, isEmpty); // Zero fake PRs on baseline

        // Save baseline to LocalStorage
        await LocalStorage.saveWorkoutSession(baselineSession);

        // 3.2 Subsequent Session with Weight PR (85.0kg > 80.0kg)
        final prSets = [
          const WorkoutSessionSet(
            setNumber: 1,
            weight: 85.0,
            reps: 8,
            completed: true,
          ),
          const WorkoutSessionSet(
            setNumber: 2,
            weight: 85.0,
            reps: 8,
            completed: true,
          ),
        ];
        final prEx = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          sets: prSets,
          isCompleted: true,
        );

        final detectedPRs = overloadService.evaluatePersonalRecords(
          exercises: [prEx],
          workoutId: 'push_02',
          pastSessions: [baselineSession],
        );

        expect(detectedPRs, isNotEmpty);
        expect(detectedPRs.first.displayText, contains('Weight PR 85.0 kg'));
        expect(detectedPRs.first.displayText, contains('+5.0 kg'));
      },
    );

    test('4. Rest Timer Service (Smart Durations & Timer Controls)', () {
      final timerService = RestTimerService.instance;

      // 4.1 Recommended durations
      const compoundEx = Exercise(
        id: 'squat',
        name: 'Barbell Back Squat',
        category: 'legs',
        equipment: 'Barbell',
        difficulty: 'Advanced',
        exerciseType: 'compound',
      );
      const isoEx = Exercise(
        id: 'bicep_curl',
        name: 'Dumbbell Bicep Curl',
        category: 'arms',
        equipment: 'Dumbbells',
        difficulty: 'Beginner',
        exerciseType: 'isolation',
      );

      expect(
        timerService.calculateRecommendedRestSeconds(compoundEx),
        equals(180),
      );
      expect(timerService.calculateRecommendedRestSeconds(isoEx), equals(60));
      expect(
        timerService.calculateRecommendedRestSeconds('Incline Dumbbell Press'),
        equals(90),
      );

      // 4.2 Timer Controls: Start, Pause, Resume, Extend, Skip
      timerService.startRest(
        durationSeconds: 90,
        exerciseName: 'Incline Press',
      );
      expect(timerService.isResting, isTrue);
      expect(timerService.isPaused, isFalse);
      expect(timerService.remainingSeconds, equals(90));

      // Pause
      timerService.pause();
      expect(timerService.isPaused, isTrue);

      // Resume
      timerService.resume();
      expect(timerService.isPaused, isFalse);

      // Extend +30s
      timerService.extend(seconds: 30);
      expect(timerService.remainingSeconds, equals(120));

      // Skip
      timerService.skip();
      expect(timerService.isResting, isFalse);
      expect(timerService.remainingSeconds, equals(0));
    });

    test(
      '5. Progressive Overload Performance Comparison & Next Target Recommendations',
      () {
        final overloadService = ProgressiveOverloadService.instance;

        final pastSession = WorkoutSession(
          id: 'sess_prev',
          workoutId: 'push_prev',
          workoutName: 'Push Session',
          startTime: DateTime.now().subtract(const Duration(days: 5)),
          endTime: DateTime.now().subtract(const Duration(days: 5)),
          exercises: [
            const WorkoutSessionExercise(
              id: 'bench_press',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 80.0,
                  reps: 8,
                  completed: true,
                ),
                WorkoutSessionSet(
                  setNumber: 2,
                  weight: 80.0,
                  reps: 8,
                  completed: true,
                ),
              ],
              isCompleted: true,
            ),
          ],
          completedExercises: 1,
          totalVolume: 1280.0,
          caloriesBurned: 150.0,
          duration: const Duration(minutes: 30),
        );

        // User hits 80.0kg x 10 reps (Rep PR)
        final feedback = overloadService.comparePerformance(
          exerciseName: 'Barbell Bench Press',
          currentWeight: 80.0,
          currentReps: 10,
          history: [pastSession],
        );

        expect(feedback.isProgression, isTrue);
        expect(feedback.isRepPR, isTrue);
        expect(
          feedback.recommendedNextWeight,
          equals(82.5),
        ); // +2.5kg upper body overload
        expect(
          feedback.recommendationMessage,
          contains('Increase weight to 82.5kg'),
        );
      },
    );

    test('6. Workout History & Offline LocalStorage Persistence', () async {
      final session = WorkoutSession(
        id: 'sess_offline_01',
        workoutId: 'leg_power_01',
        workoutName: 'Leg Day Strength',
        startTime: DateTime.now().subtract(const Duration(minutes: 45)),
        endTime: DateTime.now(),
        exercises: [
          const WorkoutSessionExercise(
            id: 'deadlift',
            name: 'Conventional Barbell Deadlift',
            muscleGroup: 'Back & Legs',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 120.0,
                reps: 6,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 125.0,
                reps: 5,
                completed: true,
              ),
            ],
            isCompleted: true,
          ),
        ],
        completedExercises: 1,
        totalVolume: 1345.0,
        caloriesBurned: 320.0,
        duration: const Duration(minutes: 45),
        personalRecords: const [
          'Conventional Barbell Deadlift: Weight PR 125.0 kg (+5.0 kg)',
        ],
        xpEarned: 350,
      );

      // Convert to WorkoutHistory and verify all properties mapped
      final historyEntry = session.toWorkoutHistory();
      expect(historyEntry.workoutName, equals('Leg Day Strength'));
      expect(historyEntry.totalVolume, equals(1345.0));
      expect(historyEntry.personalRecords.length, equals(1));
      expect(historyEntry.xpEarned, equals(350));

      // Save to LocalStorage (Offline test)
      await LocalStorage.saveWorkoutSession(session);
      await LocalStorage.saveWorkoutCompletion(historyEntry);

      final retrievedSessions = LocalStorage.getWorkoutSessions();
      final retrievedHistory = LocalStorage.getWorkoutHistory();

      expect(retrievedSessions.any((s) => s.id == 'sess_offline_01'), isTrue);
      expect(
        retrievedHistory.any((h) => h.workoutName == 'Leg Day Strength'),
        isTrue,
      );
    });

    test(
      '7. FitnessProvider completeWorkoutSession Pipeline (XP, Streaks & Memory)',
      () async {
        final provider = FitnessProvider.instance;

        final session = WorkoutSession(
          id: 'sess_provider_01',
          workoutId: 'upper_hypertrophy_01',
          workoutName: 'Upper Body Hypertrophy',
          startTime: DateTime.now().subtract(const Duration(minutes: 40)),
          endTime: DateTime.now(),
          exercises: [
            const WorkoutSessionExercise(
              id: 'incline_db_press',
              name: 'Incline Dumbbell Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 28.0,
                  reps: 10,
                  completed: true,
                ),
                WorkoutSessionSet(
                  setNumber: 2,
                  weight: 28.0,
                  reps: 10,
                  completed: true,
                ),
              ],
              isCompleted: true,
            ),
          ],
          completedExercises: 1,
          totalVolume: 560.0,
          caloriesBurned: 220.0,
          duration: const Duration(minutes: 40),
          personalRecords: const [
            'Incline Dumbbell Press: Weight PR 28.0 kg (+2.0 kg)',
          ],
          xpEarned: 250,
        );

        final initialStreak = provider.userProgress.workoutStreak;
        final initialXP = provider.userProgress.totalXP;

        final result = await provider.completeWorkoutSession(session);

        expect(result.xpEarned, greaterThanOrEqualTo(250));
        expect(provider.userProgress.totalXP, greaterThan(initialXP));
        expect(
          provider.userProgress.workoutStreak,
          greaterThanOrEqualTo(initialStreak),
        );

        // Check AI Fitness Memory was notified
        final events = FitnessMemory.instance.getEvents();
        expect(
          events.any(
            (e) =>
                e.target.contains('Upper Body Hypertrophy') ||
                e.target.contains('Incline Dumbbell Press'),
          ),
          isTrue,
        );
      },
    );

    test('8. AI Coach Prompt Integration ([RECENT PERFORMANCE] Block)', () async {
      const promptBuilder = CoachPromptBuilder();

      final session = WorkoutSession(
        id: 'sess_prompt_01',
        workoutId: 'push_test_01',
        workoutName: 'Upper Push Power',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        exercises: [
          const WorkoutSessionExercise(
            id: 'bench_press',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 90.0,
                reps: 8,
                completed: true,
              ),
            ],
            isCompleted: true,
          ),
        ],
        completedExercises: 1,
        totalVolume: 720.0,
        caloriesBurned: 180.0,
        duration: const Duration(minutes: 40),
        personalRecords: const [
          'Barbell Bench Press: Weight PR 90.0 kg (+5.0 kg)',
        ],
      );

      await LocalStorage.saveWorkoutSession(session);
      await LocalStorage.saveWorkoutCompletion(session.toWorkoutHistory());
      FitnessProvider.instance.refreshWorkoutHistory();

      final prompt = promptBuilder.buildPrompt(
        message:
            'Should I increase my bench press weight on my next chest workout?',
        context: FitnessProvider.instance.buildFitnessContext(),
        intent: AIRequestIntent.workoutRequest,
      );

      expect(prompt.contains('[RECENT PERFORMANCE]'), isTrue);
      expect(prompt.contains('Last Workout: Upper Push Power'), isTrue);
      expect(prompt.contains('Barbell Bench Press: 90.0kg x 8 reps'), isTrue);
    });

    test('9. Workout Execution State Machine (WorkoutExecutionService)', () {
      final execService = WorkoutExecutionService.instance;
      execService.initializeSession(
        workoutName: 'Chest & Triceps Power',
        workoutId: 'chest_tri_01',
        initialExercises: [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'primaryTarget': 'Chest',
            'sets': [
              {'reps': 8, 'weight': 80.0, 'completed': false},
              {'reps': 8, 'weight': 80.0, 'completed': false},
            ],
          },
        ],
      );

      // Initial state: notStarted
      expect(execService.state, equals(WorkoutSessionState.notStarted));
      expect(execService.isActive, isFalse);

      // Transition to active
      execService.startWorkout();
      expect(execService.state, equals(WorkoutSessionState.active));
      expect(execService.isActive, isTrue);

      // Start set
      execService.startSet();
      expect(execService.isSetActive, isTrue);

      // Complete set
      final isFinished = execService.completeSet();
      expect(isFinished, isFalse);
      expect(execService.isSetActive, isFalse);
      expect(execService.currentSetIndex, equals(1));

      // Transition to paused
      execService.pauseWorkout();
      expect(execService.state, equals(WorkoutSessionState.paused));
      expect(execService.isPaused, isTrue);

      // Transition back to active
      execService.startWorkout();
      expect(execService.state, equals(WorkoutSessionState.active));

      // Finalize session
      final session = execService.finalizeSession(notes: 'Great workout');
      expect(execService.state, equals(WorkoutSessionState.completed));
      expect(session.state, equals(WorkoutSessionState.completed));
      expect(session.completed, isTrue);
      expect(session.notes, equals('Great workout'));
    });
  });
}
