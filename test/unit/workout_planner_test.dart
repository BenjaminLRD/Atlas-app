import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/adaptive_workout_plan.dart';
import 'package:atlas/models/recommended_workout.dart';
import 'package:atlas/models/training_state.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/workout_planner_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    WorkoutPlannerService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('Adaptive Workout Models Unit Tests', () {
    test('RecommendedWorkout & AdaptiveWorkoutPlan serialization', () {
      final rec = RecommendedWorkout(
        id: 'r_1',
        title: 'Upper Push Power',
        focusMuscleGroups: const ['Chest', 'Triceps'],
        intensity: 'heavy',
        exercises: const ['Bench Press', 'Incline Press'],
        reason: 'Optimal readiness',
        estimatedDuration: 45,
      );

      final json = rec.toJson();
      expect(json['id'], equals('r_1'));
      expect(json['intensity'], equals('heavy'));

      final parsed = RecommendedWorkout.fromJson(json);
      expect(parsed.title, equals('Upper Push Power'));

      final plan = AdaptiveWorkoutPlan(
        id: 'plan_1',
        goalType: 'build_muscle',
        fitnessLevel: 'intermediate',
        sessions: [rec],
        generatedAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

      final planJson = plan.toJson();
      expect(planJson['id'], equals('plan_1'));
      expect(planJson['sessions'], isNotEmpty);
    });
  });

  group('WorkoutPlannerService Unit Tests', () {
    test(
      'getTodayRecommendation recommends recovery session when fatigue is high',
      () {
        final service = WorkoutPlannerService.instance;
        final state = TrainingState(
          id: 'ts_fatigue',
          fatigueScore: 75,
          readinessScore: 35,
          recommendation: 'Rest required',
          lastUpdated: DateTime.now(),
        );

        final rec = service.getTodayRecommendation(trainingState: state);
        expect(rec.intensity, equals('recovery'));
        expect(
          rec.title.contains('Mobility') || rec.title.contains('Restorative'),
          isTrue,
        );
        expect(rec.structuredExercises, isNotEmpty);
      },
    );

    test(
      'getTodayRecommendation adjusts muscle focus based on 48h workout history',
      () {
        final service = WorkoutPlannerService.instance;
        final now = DateTime.now();

        final history = [
          WorkoutHistory(
            workoutName: 'Heavy Bench Press & Chest',
            dateCompleted: now.subtract(const Duration(hours: 12)),
            durationSeconds: 3600,
            exercisesCompleted: 5,
            completionPercentage: 1.0,
          ),
        ];

        final rec = service.getTodayRecommendation(
          goal: UserGoal(
            id: 'g_1',
            goalType: FitnessGoalType.muscleGain,
            fitnessLevel: FitnessLevel.intermediate,
            activityLevel: ActivityLevel.moderate,
            age: 25,
            height: 175,
            currentWeight: 75,
            targetWeight: 80,
            targetCalories: 2500,
            targetProtein: 160,
            targetCarbohydrates: 250,
            targetFats: 70,
            createdDate: DateTime.now(),
            updatedDate: DateTime.now(),
          ),
          workoutHistory: history,
        );

        expect(rec.focusMuscleGroups.contains('Chest'), isFalse);
        expect(
          rec.focusMuscleGroups.contains('Back') ||
              rec.focusMuscleGroups.contains('Biceps'),
          isTrue,
        );
        expect(rec.structuredExercises, isNotEmpty);
        for (final ex in rec.structuredExercises) {
          expect(ex['name'], isNotNull);
          expect(ex['sets'], isNotNull);
          expect(ex['reps'], isNotNull);
        }
      },
    );

    test(
      'generatePlan builds all sessions through WorkoutGeneratorEngine with structuredExercises',
      () {
        final service = WorkoutPlannerService.instance;
        final plan = service.generatePlan();

        expect(plan.sessions, isNotEmpty);
        for (final session in plan.sessions) {
          expect(session.exercises, isNotEmpty);
          expect(session.structuredExercises, isNotEmpty);
          for (final ex in session.structuredExercises) {
            expect(ex['id'], isNotNull);
            expect(ex['name'], isNotNull);
            expect(ex['primaryTarget'], isNotNull);
            expect(ex['sets'], isA<List>());
          }
        }
      },
    );
  });

  group('FitnessProvider Adaptive Planner Integration Tests', () {
    test(
      'generateWorkoutPlan populates adaptiveWorkoutPlan and todaysRecommendation',
      () async {
        final provider = FitnessProvider.instance;
        await provider.generateWorkoutPlan();

        expect(provider.adaptiveWorkoutPlan, isNotNull);
        expect(provider.todaysRecommendation, isNotNull);
        expect(provider.todaysRecommendation!.structuredExercises, isNotEmpty);
      },
    );
  });
}
