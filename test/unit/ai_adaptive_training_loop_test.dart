import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/services/ai/adaptation/adaptation_engine.dart';
import 'package:atlas/services/ai/adaptation/training_adjustment.dart';
import 'package:atlas/services/ai/adaptation/workout_performance_analyzer.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutPerformanceAnalyzer analyzer;
  late AdaptationEngine adaptationEngine;
  late FitnessMemory memory;

  setUp(() {
    memory = FitnessMemory.instance;
    analyzer = WorkoutPerformanceAnalyzer(fitnessMemory: memory);
    adaptationEngine = AdaptationEngine(analyzer: analyzer);
  });

  group('AI Adaptive Training Loop Tests', () {
    test('1. Too Easy Detection prescribes +5% weight increase', () async {
      final session = WorkoutPerformanceData(
        workoutName: 'Push Hypertrophy',
        dateCompleted: DateTime.now(),
        exercises: [
          const ExercisePerformance(
            exerciseName: 'Barbell Bench Press',
            plannedSets: 3,
            completedSets: 3,
            targetReps: 10,
            actualReps: 15,
            targetWeight: 80.0,
            actualWeight: 80.0,
            rpe: 5.5,
          ),
        ],
      );

      final adjustments = await analyzer.analyzeSession(session);
      expect(adjustments, isNotEmpty);
      final adj = adjustments.first;
      expect(adj.adjustmentType, AdjustmentType.increaseWeight);
      expect(adj.weightMultiplier, 1.05);
      expect(adj.recommendedChange, contains('5%'));
      expect(adj.affectedExercise, 'Barbell Bench Press');
    });

    test(
      '2. Too Difficult Detection prescribes load/volume reduction',
      () async {
        final session = WorkoutPerformanceData(
          workoutName: 'Leg Day',
          dateCompleted: DateTime.now(),
          exercises: [
            const ExercisePerformance(
              exerciseName: 'Barbell Back Squat',
              plannedSets: 4,
              completedSets: 2, // Incomplete sets
              targetReps: 8,
              actualReps: 6,
              targetWeight: 100.0,
              actualWeight: 100.0,
              rpe: 9.5,
            ),
            const ExercisePerformance(
              exerciseName: 'Overhead Shoulder Press',
              plannedSets: 3,
              completedSets: 3,
              targetReps: 10,
              actualReps: 6, // Missed reps
              targetWeight: 50.0,
              actualWeight: 50.0,
              rpe: 9.8,
            ),
          ],
        );

        final adjustments = await analyzer.analyzeSession(session);
        expect(adjustments.length, 2);

        final squatAdj = adjustments.firstWhere(
          (a) => a.affectedExercise == 'Barbell Back Squat',
        );
        expect(squatAdj.adjustmentType, AdjustmentType.decreaseVolume);
        expect(squatAdj.setsDelta, -1);

        final pressAdj = adjustments.firstWhere(
          (a) => a.affectedExercise == 'Overhead Shoulder Press',
        );
        expect(pressAdj.adjustmentType, AdjustmentType.decreaseWeight);
        expect(pressAdj.weightMultiplier, 0.90);
      },
    );

    test(
      '3. Plateau Detection flags static load/reps across 3 consecutive sessions',
      () {
        final history = [
          WorkoutPerformanceData(
            workoutName: 'Push A',
            dateCompleted: DateTime.now().subtract(const Duration(days: 14)),
            exercises: const [
              ExercisePerformance(
                exerciseName: 'Barbell Bench Press',
                actualWeight: 80.0,
                actualReps: 8,
              ),
            ],
          ),
          WorkoutPerformanceData(
            workoutName: 'Push B',
            dateCompleted: DateTime.now().subtract(const Duration(days: 7)),
            exercises: const [
              ExercisePerformance(
                exerciseName: 'Barbell Bench Press',
                actualWeight: 80.0,
                actualReps: 8,
              ),
            ],
          ),
          WorkoutPerformanceData(
            workoutName: 'Push C',
            dateCompleted: DateTime.now(),
            exercises: const [
              ExercisePerformance(
                exerciseName: 'Barbell Bench Press',
                actualWeight: 80.0,
                actualReps: 8,
              ),
            ],
          ),
        ];

        final plateaus = analyzer.detectPlateaus(history);
        expect(plateaus, isNotEmpty);
        expect(plateaus.first.adjustmentType, AdjustmentType.plateauBreak);
        expect(plateaus.first.affectedExercise, 'Barbell Bench Press');
        expect(plateaus.first.recommendedChange, contains('Plateau detected'));
      },
    );

    test(
      '4. Exercise preference learning updates FitnessMemory on substitution or skip',
      () async {
        final session = WorkoutPerformanceData(
          workoutName: 'Chest Session',
          dateCompleted: DateTime.now(),
          exercises: const [
            ExercisePerformance(
              exerciseName: 'Barbell Bench Press',
              wasReplaced: true,
              replacedWith: 'Dumbbell Bench Press',
            ),
            ExercisePerformance(
              exerciseName: 'Cable Crossover',
              wasSkipped: true,
            ),
          ],
        );

        final adjustments = await analyzer.analyzeSession(session);
        expect(adjustments.length, 2);

        final repAdj = adjustments.firstWhere(
          (a) => a.affectedExercise == 'Barbell Bench Press',
        );
        expect(repAdj.adjustmentType, AdjustmentType.exerciseSwap);
        expect(repAdj.suggestedReplacement, 'Dumbbell Bench Press');

        final prefProfile = memory.getPreferenceProfile();
        expect(
          prefProfile.preferredExercises,
          contains('Dumbbell Bench Press'),
        );
        expect(prefProfile.dislikedExercises, contains('Cable Crossover'));
      },
    );

    test(
      '5. AdaptationEngine modifies candidate workout sets, weights, and explanations',
      () {
        final baseExercises = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'sets': 3,
            'reps': 10,
            'weight': 80.0,
            'defaultWeight': 80.0,
          },
          {
            'id': 'overhead_press',
            'name': 'Overhead Shoulder Press',
            'sets': 4,
            'reps': 8,
            'weight': 50.0,
            'defaultWeight': 50.0,
          },
        ];

        final adjustments = [
          const TrainingAdjustment(
            adjustmentType: AdjustmentType.increaseWeight,
            affectedExercise: 'Barbell Bench Press',
            reason: 'Progressive overload',
            recommendedChange: 'Increase load by 5%',
            weightMultiplier: 1.05,
          ),
          const TrainingAdjustment(
            adjustmentType: AdjustmentType.decreaseVolume,
            affectedExercise: 'Overhead Shoulder Press',
            reason: 'Fatigue management',
            recommendedChange: 'Reduce sets by 1',
            setsDelta: -1,
          ),
        ];

        final result = adaptationEngine.applyAdaptations(
          baseExercises: baseExercises,
          adjustments: adjustments,
        );

        expect(result.summary.hasAdaptations, isTrue);
        expect(result.summary.adjustmentsApplied.length, 2);
        expect(
          result.summary.coachExplanation,
          contains('Your workout was adapted'),
        );

        final adaptedBench = result.adaptedExercises.firstWhere(
          (e) => e['name'] == 'Barbell Bench Press',
        );
        expect(adaptedBench['weight'], 84.0); // 80 * 1.05 = 84.0

        final adaptedPress = result.adaptedExercises.firstWhere(
          (e) => e['name'] == 'Overhead Shoulder Press',
        );
        expect(adaptedPress['sets'], 3); // 4 - 1 = 3
      },
    );

    test(
      '6. Full WorkoutTool generation pipeline applies performance telemetry adaptations',
      () async {
        final workoutTool = WorkoutTool();

        final performanceData = {
          'workoutName': 'Upper Push Blast',
          'dateCompleted': DateTime.now().toIso8601String(),
          'exercises': [
            {
              'exerciseName': 'Incline Dumbbell Press',
              'plannedSets': 3,
              'completedSets': 3,
              'targetReps': 10,
              'actualReps': 15,
              'targetWeight': 24.0,
              'actualWeight': 24.0,
              'rpe': 5.0,
            },
          ],
        };

        final result = await workoutTool.execute({
          'action': 'generate_workout',
          'muscle_group': 'push',
          'duration_minutes': 45,
          'performance_data': performanceData,
        });

        expect(result['status'], 'success');
        final workout = result['workout'] as Map<String, dynamic>;
        expect(workout['adaptation'], isNotNull);
        final adaptation = workout['adaptation'] as Map<String, dynamic>;
        expect(adaptation['hasAdaptations'], isTrue);

        final explanation = (workout['ai_explanation'] as List).join(' ');
        expect(explanation, contains('Your workout was adapted'));
      },
    );
  });
}
