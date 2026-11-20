import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_intelligence_report.dart';
import 'package:atlas/services/ai/workout_intelligence_engine.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutIntelligenceEngine engine;

  setUp(() {
    engine = WorkoutIntelligenceEngine();
  });

  group('WorkoutIntelligenceEngine Unit & Pipeline Tests', () {
    test(
      '1. Hypertrophy workout scoring produces high quality score (>85)',
      () {
        final exercises = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell & Bench',
            'exerciseType': 'compound',
            'sets': 4,
            'reps': 10,
          },
          {
            'id': 'incline_dumbbell_press',
            'name': 'Incline Dumbbell Press',
            'muscleGroup': 'Chest, Front Deltoids',
            'equipment': 'Dumbbells & Incline Bench',
            'exerciseType': 'compound',
            'sets': 3,
            'reps': 10,
          },
          {
            'id': 'dips',
            'name': 'Chest Dips',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Dip Station',
            'exerciseType': 'compound',
            'sets': 3,
            'reps': 12,
          },
          {
            'id': 'tricep_pushdown',
            'name': 'Tricep Rope Pushdown',
            'muscleGroup': 'Triceps',
            'equipment': 'Cable Machine',
            'exerciseType': 'isolation',
            'sets': 3,
            'reps': 12,
          },
        ];

        final report = engine.evaluateWorkout(
          exercises: exercises,
          focus: 'push',
          durationMinutes: 45,
          goal: 'hypertrophy',
          currentRecoveryScore: 85,
        );

        expect(report.overallScore, greaterThan(85));
        expect(report.goalAlignmentScore, greaterThanOrEqualTo(90));
        expect(report.strengths, isNotEmpty);
        expect(report.aiExplanation, isNotEmpty);
      },
    );

    test('2. Bad muscle balance detection flags single-muscle dominance', () {
      // 4 Chest-only exercises with 0 shoulder or tricep movements
      final imbalancedExercises = [
        {
          'id': 'bench_press',
          'name': 'Barbell Bench Press',
          'muscleGroup': 'Chest',
          'equipment': 'Barbell & Bench',
          'exerciseType': 'compound',
          'sets': 3,
          'reps': 10,
        },
        {
          'id': 'incline_dumbbell_press',
          'name': 'Incline Dumbbell Press',
          'muscleGroup': 'Chest',
          'equipment': 'Dumbbells',
          'exerciseType': 'compound',
          'sets': 3,
          'reps': 10,
        },
        {
          'id': 'cable_flyes',
          'name': 'Standing Cable Flyes',
          'muscleGroup': 'Chest',
          'equipment': 'Cable Machine',
          'exerciseType': 'isolation',
          'sets': 3,
          'reps': 12,
        },
        {
          'id': 'pec_deck',
          'name': 'Pec Deck Machine',
          'muscleGroup': 'Pectorals',
          'equipment': 'Machine',
          'exerciseType': 'isolation',
          'sets': 3,
          'reps': 12,
        },
      ];

      final report = engine.evaluateWorkout(
        exercises: imbalancedExercises,
        focus: 'push',
        durationMinutes: 45,
        goal: 'hypertrophy',
      );

      expect(report.muscleBalanceScore, lessThan(80));
      expect(
        report.recommendations.any(
          (r) => r.toLowerCase().contains('chest volume is excessive'),
        ),
        isTrue,
      );
    });

    test(
      '3. Recovery adjustment scores autoregulation properly on low vs high readiness',
      () {
        // Light routine: 2 exercises, 6 total sets
        final lightExercises = [
          {
            'id': 'push_ups',
            'name': 'Bodyweight Push-Ups',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Bodyweight',
            'sets': 3,
            'reps': 10,
          },
          {
            'id': 'tricep_pushdown',
            'name': 'Tricep Rope Pushdown',
            'muscleGroup': 'Triceps',
            'equipment': 'Cable Machine',
            'sets': 3,
            'reps': 12,
          },
        ];

        // Low recovery readiness (35%) with light routine -> high recovery compatibility
        final lowRecoveryReport = engine.evaluateWorkout(
          exercises: lightExercises,
          focus: 'push',
          durationMinutes: 30,
          currentRecoveryScore: 35,
        );

        expect(
          lowRecoveryReport.recoveryCompatibilityScore,
          greaterThanOrEqualTo(90),
        );
        expect(
          lowRecoveryReport.aiExplanation.any(
            (e) => e.contains('35%') || e.toLowerCase().contains('scaled back'),
          ),
          isTrue,
        );

        // Heavy routine: 6 exercises, 24 total sets on low recovery -> low compatibility
        final heavyExercises = List.generate(
          6,
          (i) => {
            'id': 'ex_$i',
            'name': 'Heavy Exercise $i',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell',
            'sets': 4,
            'reps': 10,
          },
        );

        final overtrainedReport = engine.evaluateWorkout(
          exercises: heavyExercises,
          focus: 'push',
          durationMinutes: 60,
          currentRecoveryScore: 35,
        );

        expect(overtrainedReport.recoveryCompatibilityScore, lessThan(75));
        expect(
          overtrainedReport.recommendations.any(
            (r) => r.toLowerCase().contains('reducing workout'),
          ),
          isTrue,
        );
      },
    );

    test(
      '4. Progressive overload detection compares with prior workout history',
      () {
        final history = [
          WorkoutHistory(
            workoutName: 'Push Hypertrophy Session',
            dateCompleted: DateTime.now().subtract(const Duration(days: 4)),
            durationSeconds: 2400,
            exercisesCompleted: 3,
            completionPercentage: 100.0,
            totalSets: 9,
            totalReps: 90,
            totalVolume: 3200.0,
          ),
        ];

        final currentExercises = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest',
            'sets': 4,
            'reps': 10,
          },
          {
            'id': 'incline_dumbbell_press',
            'name': 'Incline Dumbbell Press',
            'muscleGroup': 'Chest',
            'sets': 4,
            'reps': 10,
          },
          {
            'id': 'dips',
            'name': 'Chest Dips',
            'muscleGroup': 'Chest, Triceps',
            'sets': 3,
            'reps': 10,
          },
        ];

        final report = engine.evaluateWorkout(
          exercises: currentExercises,
          focus: 'push',
          durationMinutes: 45,
          workoutHistory: history,
        );

        expect(report.progressionScore, greaterThanOrEqualTo(90));
        expect(
          report.aiExplanation.any(
            (e) =>
                e.toLowerCase().contains('strength progression detected') ||
                e.toLowerCase().contains('progressive overload'),
          ),
          isTrue,
        );
      },
    );

    test(
      '5. Preference personalization boosts score when favorites are included and dislikes avoided',
      () async {
        final memory = FitnessMemory.instance;
        await memory.recordExercisePreference(
          exercise: 'Barbell Bench Press',
          isPreferred: true,
        );
        await memory.recordExercisePreference(
          exercise: 'Barbell Back Squat',
          isPreferred: false,
        );

        final exercises = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell & Bench',
          },
          {
            'id': 'incline_dumbbell_press',
            'name': 'Incline Dumbbell Press',
            'muscleGroup': 'Chest',
            'equipment': 'Dumbbells',
          },
        ];

        final report = engine.evaluateWorkout(
          exercises: exercises,
          focus: 'push',
          durationMinutes: 45,
        );

        expect(report.personalizationScore, greaterThanOrEqualTo(90));
        expect(report.strengths.any((s) => s.contains('favorite')), isTrue);
      },
    );

    test(
      '6. Full AI generation pipeline includes validation, intelligence report, and coach explanation',
      () async {
        final workoutTool = WorkoutTool();
        final result = await workoutTool.execute({
          'action': 'generate_workout',
          'muscle_group': 'push',
          'duration_minutes': 45,
          'goal': 'hypertrophy',
        });

        expect(result['status'], 'success');
        final workout = result['workout'] as Map<String, dynamic>;
        expect(workout['title'], isNotEmpty);
        expect(workout['validation'], isNotNull);
        expect(workout['intelligence'], isNotNull);
        expect(workout['ai_explanation'], isNotEmpty);

        final intelligence = WorkoutIntelligenceReport.fromJson(
          Map<String, dynamic>.from(workout['intelligence'] as Map),
        );

        expect(intelligence.overallScore, greaterThan(80));
        expect(intelligence.goalAlignmentScore, greaterThan(80));
        expect(intelligence.aiExplanation, isNotEmpty);
      },
    );
  });
}
