import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/models/workout_history.dart';

void main() {
  group('WorkoutSessionSet Unit Tests', () {
    test('Calculates volume only from completed sets', () {
      const setCompleted = WorkoutSessionSet(
        setNumber: 1,
        weight: 80.0,
        reps: 10,
        completed: true,
      );
      expect(setCompleted.volume, equals(800.0));

      const setIncomplete = WorkoutSessionSet(
        setNumber: 2,
        weight: 80.0,
        reps: 8,
        completed: false,
      );
      expect(setIncomplete.volume, equals(0.0));
    });

    test('Serialization and deserialization roundtrip', () {
      const original = WorkoutSessionSet(
        setNumber: 1,
        weight: 100.0,
        reps: 5,
        completed: true,
        rpe: 8.5,
        previousWeight: 95.0,
        previousReps: 5,
        isPR: true,
      );

      final json = original.toJson();
      final restored = WorkoutSessionSet.fromJson(json);

      expect(restored.setNumber, equals(1));
      expect(restored.weight, equals(100.0));
      expect(restored.reps, equals(5));
      expect(restored.completed, isTrue);
      expect(restored.rpe, equals(8.5));
      expect(restored.previousWeight, equals(95.0));
      expect(restored.previousReps, equals(5));
      expect(restored.isPR, isTrue);
    });

    test('copyWith produces correct cloned instances', () {
      const original = WorkoutSessionSet(
        setNumber: 1,
        weight: 60.0,
        reps: 12,
        completed: false,
      );

      final modified = original.copyWith(
        weight: 65.0,
        completed: true,
        isPR: true,
      );

      expect(modified.setNumber, equals(1));
      expect(modified.weight, equals(65.0));
      expect(modified.reps, equals(12));
      expect(modified.completed, isTrue);
      expect(modified.isPR, isTrue);
    });
  });

  group('WorkoutSessionExercise Unit Tests', () {
    test('Calculates totalVolume and maxWeight strictly from completed sets', () {
      const exercise = WorkoutSessionExercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sets: [
          WorkoutSessionSet(
            setNumber: 1,
            weight: 80.0,
            reps: 10,
            completed: true,
          ), // 800
          WorkoutSessionSet(
            setNumber: 2,
            weight: 85.0,
            reps: 8,
            completed: true,
          ), // 680
          WorkoutSessionSet(
            setNumber: 3,
            weight: 90.0,
            reps: 6,
            completed: false,
          ), // 0
        ],
      );

      // Volume = 800 + 680 = 1480 (set 3 excluded because completed=false)
      expect(exercise.totalVolume, equals(1480.0));
      // Max weight among completed sets is 85.0 (90.0 excluded because incomplete)
      expect(exercise.maxWeight, equals(85.0));
      expect(exercise.totalCompletedReps, equals(18));
      expect(exercise.completedSetsCount, equals(2));
      expect(exercise.totalSetsCount, equals(3));
      expect(exercise.primaryTarget, equals('Chest'));
    });

    test('Serialization and deserialization roundtrip', () {
      const exercise = WorkoutSessionExercise(
        id: 'back_squat',
        name: 'Barbell Back Squat',
        muscleGroup: 'Legs',
        sets: [
          WorkoutSessionSet(
            setNumber: 1,
            weight: 120.0,
            reps: 5,
            completed: true,
          ),
        ],
        notes: 'Felt strong, good depth',
        isCompleted: true,
      );

      final json = exercise.toJson();
      final restored = WorkoutSessionExercise.fromJson(json);

      expect(restored.id, equals('back_squat'));
      expect(restored.name, equals('Barbell Back Squat'));
      expect(restored.muscleGroup, equals('Legs'));
      expect(restored.primaryTarget, equals('Legs'));
      expect(restored.notes, equals('Felt strong, good depth'));
      expect(restored.isCompleted, isTrue);
      expect(restored.sets.length, equals(1));
      expect(restored.sets.first.weight, equals(120.0));
    });
  });

  group('WorkoutSession Model Unit Tests', () {
    test('Calculates duration, volumes, and converts to WorkoutHistory', () {
      final startTime = DateTime(2026, 8, 23, 10, 0, 0);
      final endTime = DateTime(2026, 8, 23, 10, 45, 0);

      final session = WorkoutSession(
        id: 'session_test_01',
        workoutId: 'push_day_01',
        workoutName: 'Push Power Hypertrophy',
        startTime: startTime,
        endTime: endTime,
        duration: const Duration(minutes: 45),
        completedExercises: 2,
        totalVolume: 3200.0,
        caloriesBurned: 350.0,
        personalRecords: ['Barbell Bench Press: Weight PR 100.0 kg (+5.0 kg)'],
        xpEarned: 250,
        exercises: const [
          WorkoutSessionExercise(
            id: 'bench',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            isCompleted: true,
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 100.0,
                reps: 5,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 100.0,
                reps: 5,
                completed: true,
              ),
            ],
          ),
          WorkoutSessionExercise(
            id: 'overhead_press',
            name: 'Overhead Press',
            muscleGroup: 'Shoulders',
            isCompleted: true,
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 60.0,
                reps: 8,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 60.0,
                reps: 7,
                completed: false,
              ),
            ],
          ),
        ],
      );

      expect(session.durationSeconds, equals(2700));
      expect(session.totalSetsCount, equals(4));
      expect(session.completedSetsCount, equals(3));
      expect(session.totalCompletedReps, equals(18));
      expect(session.completionPercentage, equals(75.0));
      expect(session.calculatedTotalVolume, equals(1480.0));

      final history = session.toWorkoutHistory();
      expect(history, isA<WorkoutHistory>());
      expect(history.workoutName, equals('Push Power Hypertrophy'));
      expect(history.durationSeconds, equals(2700));
      expect(history.exercisesCompleted, equals(2));
      expect(history.completionPercentage, equals(75.0));
      expect(history.totalSets, equals(3));
      expect(history.totalReps, equals(18));
      expect(history.totalVolume, equals(3200.0));
      expect(history.caloriesBurned, equals(350.0));
      expect(history.personalRecords.length, equals(1));
      expect(history.xpEarned, equals(250));
    });

    test('Serialization and deserialization roundtrip', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 30));
      final endTime = DateTime.now();

      final session = WorkoutSession(
        id: 'session_roundtrip_101',
        workoutId: 'leg_day_01',
        workoutName: 'Leg Day Blast',
        startTime: startTime,
        endTime: endTime,
        completedExercises: 3,
        totalVolume: 5400.0,
        caloriesBurned: 420.0,
        duration: const Duration(minutes: 30),
        notes: 'Crushed the session',
        personalRecords: ['Squat: Volume PR 3000 kg'],
        xpEarned: 300,
        exercises: const [
          WorkoutSessionExercise(
            id: 'squat',
            name: 'Barbell Back Squat',
            muscleGroup: 'Legs',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 100.0,
                reps: 10,
                completed: true,
              ),
            ],
            isCompleted: true,
          ),
        ],
      );

      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);

      expect(restored.id, equals('session_roundtrip_101'));
      expect(restored.workoutId, equals('leg_day_01'));
      expect(restored.workoutName, equals('Leg Day Blast'));
      expect(restored.completedExercises, equals(3));
      expect(restored.totalVolume, equals(5400.0));
      expect(restored.caloriesBurned, equals(420.0));
      expect(restored.duration.inMinutes, equals(30));
      expect(restored.notes, equals('Crushed the session'));
      expect(restored.personalRecords, equals(['Squat: Volume PR 3000 kg']));
      expect(restored.xpEarned, equals(300));
      expect(restored.exercises.length, equals(1));
      expect(restored.exercises.first.name, equals('Barbell Back Squat'));
    });
  });
}
