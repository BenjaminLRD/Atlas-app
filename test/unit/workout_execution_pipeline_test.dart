import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/workout_service.dart';
import 'package:atlas/models/active_workout_session.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/progressive_overload_service.dart';
import 'package:atlas/services/supabase/supabase_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    ProgressiveOverloadService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('Workout Execution Pipeline End-to-End Tests', () {
    test(
      'Scenario A — First Workout: saves real volume, updates history, no fake PR',
      () async {
        final overloadService = ProgressiveOverloadService.instance;
        final workoutService = WorkoutService();

        // Bench Press: 60kg x 10, 60kg x 10, 60kg x 8
        const benchPress = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          isCompleted: true,
          sets: [
            WorkoutSessionSet(
              setNumber: 1,
              weight: 60.0,
              reps: 10,
              completed: true,
            ), // 600 kg
            WorkoutSessionSet(
              setNumber: 2,
              weight: 60.0,
              reps: 10,
              completed: true,
            ), // 600 kg
            WorkoutSessionSet(
              setNumber: 3,
              weight: 60.0,
              reps: 8,
              completed: true,
            ), // 480 kg
          ],
        );

        final totalVolume = benchPress.totalVolume;
        expect(totalVolume, equals(1680.0));

        // Evaluate PRs against empty history (First workout)
        final prResults = overloadService.evaluatePersonalRecords(
          exercises: [benchPress],
          workoutId: 'workout_chest_01',
          pastSessions: [],
        );

        // Baseline should NOT trigger fake PRs
        expect(prResults, isEmpty);

        final caloriesBurned = overloadService.calculateCaloriesBurned(
          durationSeconds: 1800,
          totalVolumeKg: totalVolume,
          completedSets: 3,
          athleteWeightKg: 75.0,
        );
        expect(caloriesBurned, greaterThan(100.0));

        final session = WorkoutSession(
          id: 'session_scenario_a',
          workoutId: 'workout_chest_01',
          workoutName: 'Chest Hypertrophy Baseline',
          startTime: DateTime.now().subtract(const Duration(minutes: 30)),
          endTime: DateTime.now(),
          exercises: const [benchPress],
          completedExercises: 1,
          totalVolume: totalVolume,
          caloriesBurned: caloriesBurned,
          duration: const Duration(minutes: 30),
          personalRecords: prResults.map((r) => r.displayText).toList(),
          xpEarned: 200,
        );

        final history = session.toWorkoutHistory();

        final provider = FitnessProvider.instance;
        await provider.saveWorkoutCompletion(history, session: session);

        // Verify persistence
        final savedSessions = workoutService.getWorkoutSessions();
        expect(savedSessions.length, equals(1));
        expect(savedSessions.first.totalVolume, equals(1680.0));
        expect(savedSessions.first.personalRecords, isEmpty);

        final savedHistory = workoutService.getWorkoutHistory();
        expect(savedHistory.length, equals(1));
        expect(
          savedHistory.first.workoutName,
          equals('Chest Hypertrophy Baseline'),
        );
        expect(savedHistory.first.totalVolume, equals(1680.0));

        // Dashboard & Provider state reflects completion
        expect(provider.workoutHistory.length, equals(1));
        expect(provider.userProgress.workoutStreak, greaterThanOrEqualTo(1));
      },
    );

    test(
      'Scenario B — Progressive Overload: detects genuine Weight PR and suggests overload',
      () async {
        final overloadService = ProgressiveOverloadService.instance;
        final workoutService = WorkoutService();

        // Prior session: Bench Press 80kg x 8 x 3 (max weight = 80kg, vol = 1920kg)
        final priorSession = WorkoutSession(
          id: 'session_prior',
          workoutId: 'workout_chest_01',
          workoutName: 'Chest Strength',
          startTime: DateTime.now().subtract(const Duration(days: 3)),
          endTime: DateTime.now().subtract(const Duration(days: 3)),
          completedExercises: 1,
          totalVolume: 1920.0,
          caloriesBurned: 220.0,
          duration: const Duration(minutes: 35),
          exercises: const [
            WorkoutSessionExercise(
              id: 'bench_press',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              isCompleted: true,
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
                WorkoutSessionSet(
                  setNumber: 3,
                  weight: 80.0,
                  reps: 8,
                  completed: true,
                ),
              ],
            ),
          ],
        );
        await workoutService.saveWorkoutSession(priorSession);

        // Current session: Bench Press 82.5kg x 8 x 3 (New max weight = 82.5kg)
        const currentExercise = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          isCompleted: true,
          sets: [
            WorkoutSessionSet(
              setNumber: 1,
              weight: 82.5,
              reps: 8,
              completed: true,
            ),
            WorkoutSessionSet(
              setNumber: 2,
              weight: 82.5,
              reps: 8,
              completed: true,
            ),
            WorkoutSessionSet(
              setNumber: 3,
              weight: 82.5,
              reps: 8,
              completed: true,
            ),
          ],
        );

        // Evaluate PRs
        final prResults = overloadService.evaluatePersonalRecords(
          exercises: const [currentExercise],
          workoutId: 'workout_chest_02',
          pastSessions: [priorSession],
        );

        expect(prResults.length, greaterThanOrEqualTo(1));
        final hasWeightPR = prResults.any(
          (p) => p.record.recordType == 'Heaviest Lift',
        );
        expect(hasWeightPR, isTrue);
        expect(prResults.first.record.value, equals(82.5));
        expect(prResults.first.record.previousValue, equals(80.0));

        // Calculate next suggested progression
        final suggestion = overloadService.getSuggestedProgression(
          exerciseName: 'Barbell Bench Press',
          exerciseId: 'bench_press',
          defaultWeight: 82.5,
          defaultReps: 8,
          prescribedTargetReps: 8,
          pastSessions: [
            WorkoutSession(
              id: 'session_current',
              workoutId: 'workout_chest_02',
              startTime: DateTime.now(),
              completedExercises: 1,
              totalVolume: currentExercise.totalVolume,
              caloriesBurned: 240.0,
              duration: const Duration(minutes: 35),
              exercises: const [currentExercise],
            ),
          ],
        );

        // Progressive overload suggested (+2.5kg or +1 rep)
        expect(suggestion.isOverloadApplied, isTrue);
        expect(suggestion.targetWeight, equals(85.0));
      },
    );

    test(
      'Scenario C — Failed Progression: maintains conservative load without auto-increasing',
      () async {
        final overloadService = ProgressiveOverloadService.instance;

        // Prior session: Bench Press 80kg x 8
        // Current session: User attempted 82.5kg but only completed 5 reps (target was 8)
        const failedExercise = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          isCompleted: false,
          sets: [
            WorkoutSessionSet(
              setNumber: 1,
              weight: 82.5,
              reps: 5,
              completed: true,
            ),
            WorkoutSessionSet(
              setNumber: 2,
              weight: 82.5,
              reps: 4,
              completed: true,
            ),
          ],
        );

        final failedSession = WorkoutSession(
          id: 'session_failed',
          workoutId: 'workout_chest_failed',
          startTime: DateTime.now(),
          completedExercises: 0,
          totalVolume: failedExercise.totalVolume,
          caloriesBurned: 150.0,
          duration: const Duration(minutes: 20),
          exercises: const [failedExercise],
        );

        final suggestion = overloadService.getSuggestedProgression(
          exerciseName: 'Barbell Bench Press',
          exerciseId: 'bench_press',
          defaultWeight: 82.5,
          defaultReps: 8,
          prescribedTargetReps: 8,
          pastSessions: [failedSession],
        );

        // Must NOT increase weight after failed progression
        expect(suggestion.isOverloadApplied, isFalse);
        expect(suggestion.targetWeight, equals(82.5));
        expect(suggestion.progressionNote, contains('Maintain'));
      },
    );

    test(
      'Scenario D — Interrupted Workout: persists and restores active session accurately',
      () async {
        final workoutService = WorkoutService();

        // Halfway completed session
        final activeSession = ActiveWorkoutSession(
          workoutName: 'Upper Push Power',
          workoutId: 'push_power_01',
          currentIndex: 1,
          currentSetIndex: 1,
          seconds: 450,
          isPaused: false,
          completedSets: [
            [true, true, true],
            [true, false, false],
          ],
          exercisesData: [
            {
              'name': 'Barbell Bench Press',
              'sets': [
                {'weight': 80.0, 'reps': 8, 'completed': true},
                {'weight': 80.0, 'reps': 8, 'completed': true},
                {'weight': 80.0, 'reps': 8, 'completed': true},
              ],
            },
            {
              'name': 'Incline Dumbbell Press',
              'sets': [
                {'weight': 30.0, 'reps': 10, 'completed': true},
                {'weight': 30.0, 'reps': 10, 'completed': false},
                {'weight': 30.0, 'reps': 10, 'completed': false},
              ],
            },
          ],
        );

        // 1. Save interrupted session
        await workoutService.saveActiveSession(activeSession);

        // 2. Reopen app and retrieve active session
        final restored = workoutService.getActiveSession();
        expect(restored, isNotNull);
        expect(restored!.workoutId, equals('push_power_01'));
        expect(restored.workoutName, equals('Upper Push Power'));
        expect(restored.currentIndex, equals(1));
        expect(restored.currentSetIndex, equals(1));
        expect(restored.seconds, equals(450));
        expect(restored.completedSets[0], equals([true, true, true]));
        expect(restored.completedSets[1][0], isTrue);
        expect(restored.completedSets[1][1], isFalse);

        // 3. Clear on completion
        await workoutService.clearActiveSession();
        expect(workoutService.getActiveSession(), isNull);
      },
    );

    test(
      'Scenario E — Offline Completion: completes locally with non-blocking cloud fallback',
      () async {
        final supabaseRepo = SupabaseWorkoutRepository();

        final session = WorkoutSession(
          id: 'session_offline_01',
          workoutId: 'workout_offline_01',
          workoutName: 'Offline Deadlift Blast',
          startTime: DateTime(2026, 8, 23, 10, 0),
          duration: const Duration(minutes: 40),
          completedExercises: 1,
          totalVolume: 3600.0,
          caloriesBurned: 310.0,
          personalRecords: const [],
          xpEarned: 220,
          exercises: const [
            WorkoutSessionExercise(
              id: 'deadlift',
              name: 'Conventional Barbell Deadlift',
              muscleGroup: 'Back',
              isCompleted: true,
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 120.0,
                  reps: 10,
                  completed: true,
                ),
                WorkoutSessionSet(
                  setNumber: 2,
                  weight: 120.0,
                  reps: 10,
                  completed: true,
                ),
                WorkoutSessionSet(
                  setNumber: 3,
                  weight: 120.0,
                  reps: 10,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        // Saving offline should write to LocalStorage without throwing unhandled exception
        await supabaseRepo.saveWorkoutSessionModel(session);

        final localSessions = LocalStorage.getWorkoutSessions();
        expect(localSessions.length, equals(1));
        expect(
          localSessions.first.workoutName,
          equals('Offline Deadlift Blast'),
        );
        expect(localSessions.first.totalVolume, equals(3600.0));

        final localHistory = LocalStorage.getWorkoutHistory();
        expect(localHistory.length, equals(1));
        expect(localHistory.first.totalVolume, equals(3600.0));
      },
    );

    test(
      'Epley 1RM PR Detection: higher 1RM with lower weight and higher reps is recognized',
      () {
        final overloadService = ProgressiveOverloadService.instance;

        // Historical Best: 100 kg x 5 reps -> 1RM = 100 * (1 + 5/30) = 116.67 kg
        final priorSession = WorkoutSession(
          id: 'session_hist_1rm',
          workoutId: 'bench_1rm_test',
          startTime: DateTime(2026, 8, 20),
          completedExercises: 1,
          totalVolume: 500.0,
          caloriesBurned: 100.0,
          duration: const Duration(minutes: 20),
          exercises: const [
            WorkoutSessionExercise(
              id: 'bench_press',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 100.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        // Current Session: 95 kg x 8 reps -> 1RM = 95 * (1 + 8/30) = 120.33 kg
        const currentExercise = WorkoutSessionExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          sets: [
            WorkoutSessionSet(
              setNumber: 1,
              weight: 95.0,
              reps: 8,
              completed: true,
            ),
          ],
        );

        final prResults = overloadService.evaluatePersonalRecords(
          exercises: const [currentExercise],
          workoutId: 'bench_1rm_test_02',
          pastSessions: [priorSession],
        );

        final oneRMResult = prResults.firstWhere(
          (p) => p.record.recordType == 'Estimated 1RM',
        );
        expect(oneRMResult.record.value, closeTo(120.33, 0.1));
        expect(oneRMResult.record.previousValue, closeTo(116.67, 0.1));

        final volResult = prResults.firstWhere(
          (p) => p.record.recordType == 'Highest Session Volume',
        );
        expect(volResult.record.value, equals(760.0));
        expect(volResult.record.previousValue, equals(500.0));
      },
    );
  });
}
