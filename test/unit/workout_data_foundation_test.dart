import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/exercise.dart';
import 'package:aizawl_gym/models/workout_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exercise Model Tests', () {
    test('creates Exercise with default values and custom parameters', () {
      const exercise = Exercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest, Triceps',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        instructions: ['Unrack bar', 'Lower to chest', 'Press up'],
        tips: ['Keep feet flat on ground'],
        commonMistakes: ['Flaring elbows'],
        imageUrl: 'assets/exercises/bench.png',
        alternatives: ['Dumbbell Press'],
      );

      expect(exercise.id, equals('bench_press'));
      expect(exercise.name, equals('Barbell Bench Press'));
      expect(exercise.muscleGroup, equals('Chest, Triceps'));
      expect(exercise.equipment, equals('Barbell'));
      expect(exercise.difficulty, equals('Intermediate'));
      expect(exercise.instructions.length, equals(3));
      expect(exercise.tips.length, equals(1));
      expect(exercise.commonMistakes.length, equals(1));
      expect(exercise.alternatives.first, equals('Dumbbell Press'));
    });

    test('Exercise.fromJson and toJson round trip', () {
      final jsonMap = {
        'id': 'squat',
        'name': 'Barbell Squat',
        'muscleGroup': 'Legs',
        'equipment': 'Barbell',
        'difficulty': 'Advanced',
        'instructions': ['Step under bar', 'Squat deep'],
        'tips': ['Keep chest up'],
        'commonMistakes': ['Heels off floor'],
        'imageUrl': 'assets/exercises/squat.png',
        'videoUrl': 'https://example.com/squat.mp4',
        'alternatives': ['Leg Press'],
      };

      final exercise = Exercise.fromJson(jsonMap);
      expect(exercise.id, equals('squat'));
      expect(exercise.videoUrl, equals('https://example.com/squat.mp4'));

      final reserialized = exercise.toJson();
      expect(reserialized['id'], equals('squat'));
      expect(reserialized['videoUrl'], equals('https://example.com/squat.mp4'));
    });

    test('Exercise.defaultRegistry provides non-empty list of structured exercises', () {
      final registry = Exercise.defaultRegistry();
      expect(registry, isNotEmpty);
      expect(registry.first.id, equals('barbell_back_squat'));
      expect(registry.first.instructions, isNotEmpty);
      expect(registry.first.commonMistakes, isNotEmpty);
    });

    test('Exercise.copyWith updates fields correctly', () {
      const exercise = Exercise(
        id: 'ex1',
        name: 'Old Name',
        muscleGroup: 'Chest',
        equipment: 'Dumbbell',
      );

      final updated = exercise.copyWith(name: 'New Name', difficulty: 'Beginner');

      expect(updated.name, equals('New Name'));
      expect(updated.difficulty, equals('Beginner'));
      expect(updated.muscleGroup, equals('Chest'));
    });
  });

  group('Enhanced WorkoutHistory Model Tests', () {
    test('creates WorkoutHistory with enhanced metric fields', () {
      final history = WorkoutHistory(
        workoutName: 'Heavy Leg Day',
        dateCompleted: DateTime(2026, 8, 4, 10, 0),
        durationSeconds: 3600,
        exercisesCompleted: 5,
        completionPercentage: 1.0,
        totalSets: 20,
        totalReps: 200,
        totalVolume: 12000.0,
        caloriesBurned: 390.0,
        personalRecords: ['Barbell Back Squat: 120.0 kg'],
        xpEarned: 420,
      );

      expect(history.workoutName, equals('Heavy Leg Day'));
      expect(history.totalSets, equals(20));
      expect(history.totalReps, equals(200));
      expect(history.totalVolume, equals(12000.0));
      expect(history.caloriesBurned, equals(390.0));
      expect(history.personalRecords.length, equals(1));
      expect(history.xpEarned, equals(420));
    });

    test('WorkoutHistory.fromJson parses new enhanced fields correctly', () {
      final jsonMap = {
        'workoutName': 'Upper Body Blast',
        'dateCompleted': '2026-08-04T10:00:00.000',
        'durationSeconds': 2400,
        'exercisesCompleted': 4,
        'completionPercentage': 1.0,
        'totalSets': 16,
        'totalReps': 160,
        'totalVolume': 8000.0,
        'caloriesBurned': 260.0,
        'personalRecords': ['Bench Press: 90.0 kg'],
        'xpEarned': 300,
      };

      final history = WorkoutHistory.fromJson(jsonMap);

      expect(history.totalSets, equals(16));
      expect(history.totalReps, equals(160));
      expect(history.totalVolume, equals(8000.0));
      expect(history.caloriesBurned, equals(260.0));
      expect(history.personalRecords, contains('Bench Press: 90.0 kg'));
      expect(history.xpEarned, equals(300));
    });

    test('WorkoutHistory.fromJson maintains backward compatibility with legacy history entries', () {
      final legacyJson = {
        'workoutName': 'Old Leg Workout',
        'dateCompleted': '2026-08-01T08:00:00.000',
        'durationSeconds': 1800,
        'exercisesCompleted': 3,
        'completionPercentage': 1.0,
      };

      final history = WorkoutHistory.fromJson(legacyJson);

      expect(history.workoutName, equals('Old Leg Workout'));
      expect(history.totalSets, equals(12)); // 3 * 4 fallback
      expect(history.totalReps, equals(120)); // 3 * 40 fallback
      expect(history.totalVolume, equals(1500.0)); // 3 * 500 fallback
      expect(history.caloriesBurned, equals(225.0)); // (30 mins * 7.5) fallback
      expect(history.personalRecords, isEmpty);
      expect(history.xpEarned, equals(150));
    });

    test('WorkoutHistory.copyWith creates copy with updated metrics', () {
      final history = WorkoutHistory(
        workoutName: 'Core Workout',
        dateCompleted: DateTime(2026, 8, 4),
        durationSeconds: 1200,
        exercisesCompleted: 3,
        completionPercentage: 0.8,
        totalSets: 12,
      );

      final updated = history.copyWith(
        completionPercentage: 1.0,
        totalSets: 15,
        xpEarned: 250,
      );

      expect(updated.completionPercentage, equals(1.0));
      expect(updated.totalSets, equals(15));
      expect(updated.xpEarned, equals(250));
      expect(updated.workoutName, equals('Core Workout'));
    });
  });
}
