import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 — Upgraded Exercise Model Tests', () {
    test('Exercise model initializes with all Phase 2 required fields', () {
      const exercise = Exercise(
        id: 'barbell_bench_press',
        name: 'Barbell Bench Press',
        category: 'strength',
        primaryMuscles: ['Chest', 'Triceps'],
        secondaryMuscles: ['Front Deltoids', 'Core'],
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        instructions: [
          'Lie flat on the bench.',
          'Lower the bar to mid-chest.',
          'Press back to lockout.',
        ],
        coachingTips: ['Drive through your feet', 'Keep wrists straight'],
        commonMistakes: ['Flaring elbows 90 degrees', 'Bouncing off chest'],
        alternatives: ['dumbbell_bench_press', 'push_ups'],
        imageUrl: 'https://example.com/bench.jpg',
        videoUrl: 'https://example.com/bench.mp4',
        estimatedCalories: 120,
        tags: ['chest', 'compound', 'barbell', 'upper_push'],
      );

      expect(exercise.id, 'barbell_bench_press');
      expect(exercise.name, 'Barbell Bench Press');
      expect(exercise.category, 'strength');
      expect(exercise.primaryMuscles, ['Chest', 'Triceps']);
      expect(exercise.secondaryMuscles, ['Front Deltoids', 'Core']);
      expect(exercise.equipment, 'Barbell');
      expect(exercise.difficulty, 'Intermediate');
      expect(exercise.movementPattern, 'push');
      expect(exercise.exerciseType, 'compound');
      expect(exercise.instructions.length, 3);
      expect(exercise.coachingTips.length, 2);
      expect(exercise.tips.length, 2);
      expect(exercise.commonMistakes.length, 2);
      expect(exercise.alternatives.length, 2);
      expect(exercise.imageUrl, 'https://example.com/bench.jpg');
      expect(exercise.videoUrl, 'https://example.com/bench.mp4');
      expect(exercise.estimatedCalories, 120);
      expect(exercise.tags, ['chest', 'compound', 'barbell', 'upper_push']);
      expect(exercise.muscleGroup, 'Chest, Triceps');
    });

    test(
      'Exercise model maintains backwards compatibility with legacy parameters',
      () {
        const legacyExercise = Exercise(
          id: 'db_curl',
          name: 'Dumbbell Bicep Curl',
          muscleGroup: 'Biceps, Forearms',
          equipment: 'Dumbbells',
          tips: ['Keep elbows tucked'],
        );

        expect(legacyExercise.id, 'db_curl');
        expect(legacyExercise.name, 'Dumbbell Bicep Curl');
        expect(legacyExercise.muscleGroup, 'Biceps, Forearms');
        expect(legacyExercise.category, 'strength');
        expect(legacyExercise.movementPattern, 'push');
        expect(legacyExercise.exerciseType, 'compound');
        expect(legacyExercise.estimatedCalories, 0);
        expect(legacyExercise.tags, isEmpty);
        expect(legacyExercise.coachingTips, ['Keep elbows tucked']);
      },
    );

    test('Exercise JSON serialization round-trip maintains Phase 2 fields', () {
      const original = Exercise(
        id: 'pull_ups',
        name: 'Pull-ups',
        category: 'strength',
        primaryMuscles: ['Lats', 'Upper Back'],
        secondaryMuscles: ['Biceps', 'Forearms', 'Core'],
        equipment: 'Bodyweight',
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'compound',
        instructions: ['Hang from bar', 'Pull chin over bar', 'Lower slowly'],
        coachingTips: ['Engage lats first'],
        commonMistakes: ['Kicking legs excessively'],
        alternatives: ['lat_pulldown', 'chin_ups'],
        estimatedCalories: 95,
        tags: ['pull', 'lats', 'back', 'bodyweight'],
      );

      final json = original.toJson();
      final restored = Exercise.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.primaryMuscles, original.primaryMuscles);
      expect(restored.secondaryMuscles, original.secondaryMuscles);
      expect(restored.equipment, original.equipment);
      expect(restored.difficulty, original.difficulty);
      expect(restored.movementPattern, original.movementPattern);
      expect(restored.exerciseType, original.exerciseType);
      expect(restored.instructions, original.instructions);
      expect(restored.coachingTips, original.coachingTips);
      expect(restored.commonMistakes, original.commonMistakes);
      expect(restored.alternatives, original.alternatives);
      expect(restored.estimatedCalories, original.estimatedCalories);
      expect(restored.tags, original.tags);
    });

    test('Exercise.copyWith updates Phase 2 fields cleanly', () {
      const base = Exercise(
        id: 'squat',
        name: 'Barbell Back Squat',
        category: 'strength',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        movementPattern: 'squat',
        exerciseType: 'compound',
      );

      final updated = base.copyWith(
        difficulty: 'Advanced',
        estimatedCalories: 150,
        tags: ['legs', 'quads', 'compound'],
      );

      expect(updated.id, 'squat');
      expect(updated.difficulty, 'Advanced');
      expect(updated.estimatedCalories, 150);
      expect(updated.tags, ['legs', 'quads', 'compound']);
      expect(updated.movementPattern, 'squat');
      expect(updated.primaryMuscles, ['Quadriceps', 'Glutes']);
    });
  });
}
