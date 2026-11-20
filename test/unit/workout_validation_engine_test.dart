import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/user_equipment_profile.dart';
import 'package:atlas/models/workout_validation_report.dart';
import 'package:atlas/services/workout_validation_engine.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutValidationEngine validationEngine;

  setUp(() {
    validationEngine = const WorkoutValidationEngine();
  });

  group('WorkoutValidationEngine Constraint Verification Tests', () {
    test(
      '1. Flawless workout passes all checks with 100/100 quality score',
      () {
        final proposed = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell & Bench',
            'sets': 4,
            'reps': 8,
          },
          {
            'id': 'incline_dumbbell_press',
            'name': 'Incline Dumbbell Press',
            'muscleGroup': 'Chest, Front Deltoids',
            'equipment': 'Dumbbells & Incline Bench',
            'sets': 3,
            'reps': 10,
          },
          {
            'id': 'dips',
            'name': 'Chest Dips',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Dip Station',
            'sets': 3,
            'reps': 12,
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

        final report = validationEngine.validateAndSanitizeWorkout(
          proposedExercises: proposed,
          focus: 'push',
          durationMinutes: 45,
          equipmentProfile: UserEquipmentProfile.fullCommercialGym(),
        );

        expect(report.isValid, isTrue);
        expect(report.qualityScore, 100);
        expect(report.violations, isEmpty);
        expect(report.hasCriticalViolations, isFalse);
        expect(report.sanitizedExercises.length, 4);
      },
    );

    test(
      '2. Detects equipment constraint violation and auto-substitutes compliant exercise',
      () {
        final proposed = [
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell & Bench',
          },
          {
            'id': 'leg_press',
            'name': 'Leg Press Machine',
            'muscleGroup': 'Quadriceps',
            'equipment': 'Leg Press Machine',
          },
        ];

        // Athlete only has dumbbells and a pull-up bar
        final dumbbellProfile = UserEquipmentProfile(
          userId: 'test_user',
          availableEquipmentIds: const ['dumbbells', 'pull_up_bar'],
          updatedAt: DateTime(2026, 1, 1),
        );

        final report = validationEngine.validateAndSanitizeWorkout(
          proposedExercises: proposed,
          focus: 'push',
          durationMinutes: 45,
          equipmentProfile: dumbbellProfile,
        );

        expect(
          report.violations.any(
            (v) => v.constraintName == 'equipment_incompatibility',
          ),
          isTrue,
        );
        expect(report.sanitizedExercises.isNotEmpty, isTrue);

        // Verify all sanitized exercises can be performed with the dumbbell profile
        for (final ex in report.sanitizedExercises) {
          final eq = (ex['equipment'] as String).toLowerCase();
          final isDumbbellOrBody =
              eq.contains('dumbbell') ||
              eq.contains('bodyweight') ||
              eq.contains('none') ||
              eq.contains('pull-up');
          expect(isDumbbellOrBody, isTrue);
        }
      },
    );

    test('3. Detects split mismatch and replaces off-focus exercises', () {
      final proposed = [
        {
          'id': 'bench_press',
          'name': 'Barbell Bench Press',
          'muscleGroup': 'Chest, Triceps',
          'equipment': 'Barbell & Bench',
        },
        {
          'id': 'deadlift',
          'name': 'Conventional Barbell Deadlift',
          'muscleGroup': 'Lower Back, Hamstrings, Glutes',
          'equipment': 'Barbell',
        },
        {
          'id': 'barbell_row',
          'name': 'Bent-Over Barbell Row',
          'muscleGroup': 'Back, Lats, Biceps',
          'equipment': 'Barbell',
        },
      ];

      final report = validationEngine.validateAndSanitizeWorkout(
        proposedExercises: proposed,
        focus: 'push',
        durationMinutes: 45,
        equipmentProfile: UserEquipmentProfile.fullCommercialGym(),
      );

      expect(
        report.violations.any((v) => v.constraintName == 'split_mismatch'),
        isTrue,
      );
      // All final sanitized exercises should be coherent with Push day
      for (final ex in report.sanitizedExercises) {
        final mg = (ex['muscleGroup'] as String).toLowerCase();
        final isPushMuscle =
            mg.contains('chest') ||
            mg.contains('tricep') ||
            mg.contains('shoulder') ||
            mg.contains('push');
        expect(isPushMuscle, isTrue);
      }
    });

    test(
      '4. Detects injury limitation and replaces high-risk movements with safe options',
      () {
        final proposed = [
          {
            'id': 'overhead_press',
            'name': 'Standing Overhead Barbell Press',
            'muscleGroup': 'Shoulders, Triceps',
            'equipment': 'Barbell',
          },
          {
            'id': 'bench_press',
            'name': 'Barbell Bench Press',
            'muscleGroup': 'Chest, Triceps',
            'equipment': 'Barbell',
          },
        ];

        final report = validationEngine.validateAndSanitizeWorkout(
          proposedExercises: proposed,
          focus: 'push',
          durationMinutes: 30,
          injuriesOrLimitations: ['Shoulder Impingement'],
        );

        expect(
          report.violations.any((v) => v.constraintName == 'injury_risk'),
          isTrue,
        );
        expect(report.sanitizedExercises.isNotEmpty, isTrue);
      },
    );

    test('5. Deduplicates repeated exercises in workout plan', () {
      final proposed = [
        {
          'id': 'bench_press',
          'name': 'Barbell Bench Press',
          'muscleGroup': 'Chest',
          'equipment': 'Barbell',
        },
        {
          'id': 'bench_press',
          'name': 'Barbell Bench Press',
          'muscleGroup': 'Chest',
          'equipment': 'Barbell',
        },
        {
          'id': 'incline_dumbbell_press',
          'name': 'Incline Dumbbell Press',
          'muscleGroup': 'Chest',
          'equipment': 'Dumbbells',
        },
      ];

      final report = validationEngine.validateAndSanitizeWorkout(
        proposedExercises: proposed,
        focus: 'push',
        durationMinutes: 30,
      );

      expect(
        report.violations.any((v) => v.constraintName == 'duplicate_exercise'),
        isTrue,
      );
      final names = report.sanitizedExercises.map((e) => e['name']).toList();
      final distinctNames = names.toSet().toList();
      expect(names.length, distinctNames.length);
    });

    test(
      '6. WorkoutTool integration executes validation and returns report payload',
      () async {
        final workoutTool = WorkoutTool();
        final result = await workoutTool.execute({
          'action': 'generate_workout',
          'muscle_group': 'pull',
          'duration_minutes': 45,
          'available_equipment': ['dumbbells', 'pull_up_bar'],
        });

        expect(result['status'], 'success');
        expect(result['action'], 'generate_workout');
        final workout = result['workout'] as Map<String, dynamic>;
        expect(workout['focus'], 'pull');
        expect(workout['exercises'], isNotEmpty);
        expect(workout['validation'], isNotNull);

        final validation = WorkoutValidationReport.fromJson(
          Map<String, dynamic>.from(workout['validation'] as Map),
        );
        expect(validation.isValid, isTrue);
        expect(validation.qualityScore, greaterThan(0));
      },
    );
  });
}
