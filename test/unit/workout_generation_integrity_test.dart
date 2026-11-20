import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/user_equipment_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/memory/preference_profile.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/exercise_media_service.dart';
import 'package:atlas/services/workout_generator_engine.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.saveProfile(PreferenceProfile.initial());
  });

  group('Workout Generation & Exercise Media Integrity Tests', () {
    final engine = WorkoutGeneratorEngine();

    test(
      '1. Upper Push & Chest workouts NEVER select Barbell Back Squat or leg exercises',
      () {
        final pushWorkouts = [
          'Upper Push Power & Chest Builder',
          'Push Hypertrophy Session',
          'Chest & Triceps Focus',
          'Incline Bench Press Power',
        ];

        for (final title in pushWorkouts) {
          final exercises = engine.generateExercisesForWorkout(
            workoutName: title,
          );
          expect(exercises.isNotEmpty, isTrue);

          for (final ex in exercises) {
            final name = ex['name'].toString().toLowerCase();
            final muscle = ex['primaryTarget'].toString().toLowerCase();

            // Strict assertion: No leg movements
            expect(
              name.contains('squat'),
              isFalse,
              reason: '$title generated squat: $name',
            );
            expect(
              name.contains('deadlift'),
              isFalse,
              reason: '$title generated deadlift: $name',
            );
            expect(
              name.contains('leg press'),
              isFalse,
              reason: '$title generated leg press: $name',
            );
            expect(
              muscle.contains('quadriceps'),
              isFalse,
              reason: '$title targeted quads: $muscle',
            );
            expect(
              muscle.contains('glute'),
              isFalse,
              reason: '$title targeted glutes: $muscle',
            );
            expect(
              muscle.contains('hamstring'),
              isFalse,
              reason: '$title targeted hamstrings: $muscle',
            );

            // Must be push-related (Chest, Shoulders, Triceps, Deltoids)
            final isPushMuscle =
                muscle.contains('chest') ||
                muscle.contains('shoulder') ||
                muscle.contains('tricep') ||
                muscle.contains('deltoid');
            expect(
              isPushMuscle,
              isTrue,
              reason: '$title had non-push muscle: $muscle for $name',
            );
          }
        }
      },
    );

    test(
      '2. Pull & Back workouts NEVER select Bench Press or Quad exercises',
      () {
        final pullWorkouts = [
          'Pull Hypertrophy & Bicep Builder',
          'Back & Biceps Technical',
          'Lats & Upper Back Overload',
        ];

        for (final title in pullWorkouts) {
          final exercises = engine.generateExercisesForWorkout(
            workoutName: title,
          );
          expect(exercises.isNotEmpty, isTrue);

          for (final ex in exercises) {
            final name = ex['name'].toString().toLowerCase();
            final muscle = ex['primaryTarget'].toString().toLowerCase();

            // Strict assertion: No chest/quad movements
            expect(
              name.contains('bench press'),
              isFalse,
              reason: '$title generated bench press: $name',
            );
            expect(
              name.contains('push-up'),
              isFalse,
              reason: '$title generated push-up: $name',
            );
            expect(
              muscle.contains('chest'),
              isFalse,
              reason: '$title targeted chest: $muscle',
            );
            expect(
              muscle.contains('quadriceps'),
              isFalse,
              reason: '$title targeted quads: $muscle',
            );

            // Must be pull-related (Back, Lats, Biceps, Rhomboids, Rear Delts)
            final isPullMuscle =
                muscle.contains('back') ||
                muscle.contains('lat') ||
                muscle.contains('bicep') ||
                muscle.contains('rhomboid') ||
                muscle.contains('trap') ||
                muscle.contains('rear deltoid');
            expect(
              isPullMuscle,
              isTrue,
              reason: '$title had non-pull muscle: $muscle for $name',
            );
          }
        }
      },
    );

    test(
      '3. Leg workouts strictly contain lower-body exercises and NO upper body presses',
      () {
        final legWorkouts = [
          'Leg Day - Hypertrophy',
          'Lower Body Strength',
          'Quads, Glutes & Calves Focus',
        ];

        for (final title in legWorkouts) {
          final exercises = engine.generateExercisesForWorkout(
            workoutName: title,
          );
          expect(exercises.isNotEmpty, isTrue);

          for (final ex in exercises) {
            final name = ex['name'].toString().toLowerCase();
            final muscle = ex['primaryTarget'].toString().toLowerCase();

            // Strict assertion: No chest/back/shoulder presses
            expect(
              name.contains('bench press'),
              isFalse,
              reason: '$title generated bench press: $name',
            );
            expect(
              name.contains('overhead press'),
              isFalse,
              reason: '$title generated overhead press: $name',
            );
            expect(
              muscle.contains('chest'),
              isFalse,
              reason: '$title targeted chest: $muscle',
            );

            // Must be lower-body related (Quads, Glutes, Hamstrings, Calves)
            final isLegMuscle =
                muscle.contains('quad') ||
                muscle.contains('glute') ||
                muscle.contains('hamstring') ||
                muscle.contains('calf') ||
                muscle.contains('leg');
            expect(
              isLegMuscle,
              isTrue,
              reason: '$title had non-leg muscle: $muscle for $name',
            );
          }
        }
      },
    );

    test(
      '4. Equipment restrictions: Dumbbell-only profile excludes Barbell and Cable exercises',
      () {
        final dumbbellOnlyProfile = UserEquipmentProfile(
          userId: 'test_db_user',
          availableEquipmentIds: const ['dumbbells', 'bench', 'exercise_mat'],
          updatedAt: DateTime.now(),
        );

        final exercises = engine.generateExercisesForWorkout(
          workoutName: 'Upper Push Power',
          equipmentProfile: dumbbellOnlyProfile,
        );

        expect(exercises.isNotEmpty, isTrue);
        for (final ex in exercises) {
          final name = ex['name'].toString().toLowerCase();
          final equipment = ex['equipment'].toString().toLowerCase();

          // Must not require barbell or cable machine
          expect(
            name.contains('barbell'),
            isFalse,
            reason: 'Dumbbell-only workout generated barbell: $name',
          );
          expect(
            equipment.contains('barbell'),
            isFalse,
            reason: 'Dumbbell-only workout equipment had barbell: $equipment',
          );
          expect(
            equipment.contains('cable'),
            isFalse,
            reason: 'Dumbbell-only workout equipment had cable: $equipment',
          );
        }
      },
    );

    test(
      '5. FitnessMemory preferences: Disliked exercises are excluded, preferred are prioritized',
      () async {
        // Configure disliked and preferred
        final customProfile = PreferenceProfile.initial().copyWith(
          dislikedExercises: ['Barbell Bench Press'],
          preferredExercises: ['Incline Dumbbell Press'],
          exerciseScores: {
            'Barbell Bench Press': -3,
            'Incline Dumbbell Press': 5,
          },
        );
        await FitnessMemory.instance.saveProfile(customProfile);

        final exercises = engine.generateExercisesForWorkout(
          workoutName: 'Upper Push Power',
        );
        final names = exercises.map((e) => e['name'].toString()).toList();

        expect(
          names.contains('Barbell Bench Press'),
          isFalse,
          reason: 'Disliked exercise was included',
        );
        expect(
          names.contains('Incline Dumbbell Press'),
          isTrue,
          reason: 'Preferred exercise was missing',
        );
      },
    );

    test(
      '6. History rotation: Provides variety without breaking muscle group rules',
      () {
        final history = [
          WorkoutHistory(
            workoutName: 'Barbell Bench Press Session',
            dateCompleted: DateTime.now().subtract(const Duration(hours: 12)),
            durationSeconds: 2400,
            exercisesCompleted: 4,
            completionPercentage: 100.0,
          ),
        ];

        final exercises = engine.generateExercisesForWorkout(
          workoutName: 'Push Hypertrophy',
          workoutHistory: history,
        );

        expect(exercises.isNotEmpty, isTrue);
        // All exercises must still be strictly push movements
        for (final ex in exercises) {
          final muscle = ex['primaryTarget'].toString().toLowerCase();
          expect(
            muscle.contains('chest') ||
                muscle.contains('shoulder') ||
                muscle.contains('tricep') ||
                muscle.contains('deltoid'),
            isTrue,
          );
        }
      },
    );

    test(
      '7. Exercise Media Determinism: Exact 1:1 media resolution with no cross-exercise fallbacks',
      () {
        final mediaService = ExerciseMediaService();
        final allExercises = Exercise.defaultRegistry();

        for (final ex in allExercises) {
          final media = mediaService.resolveMedia(ex);
          expect(media.exerciseId, equals(ex.id));

          // When no verified media exists, it must return 'placeholder' and NOT an unrelated exercise's image
          if (ex.videoUrl == null &&
              ex.animationAsset == null &&
              ex.imageUrl == null) {
            expect(media.mediaType, equals('placeholder'));
            expect(media.thumbnail, isNull);
            expect(media.url, isEmpty);
          } else if (ex.imageUrl != null) {
            expect(media.thumbnail, equals(ex.imageUrl));
          }
        }
      },
    );

    test(
      '8. WorkoutTool AI tool generates muscle-compatible workouts with full parameters',
      () async {
        final tool = WorkoutTool();

        final pushResult = await tool.execute({
          'action': 'generate_workout',
          'muscle_group': 'push',
          'duration_minutes': 45,
        });

        expect(pushResult['status'], equals('success'));
        final workoutData = pushResult['workout'] as Map<String, dynamic>;
        final exercises = workoutData['exercises'] as List;
        expect(exercises.isNotEmpty, isTrue);

        for (final ex in exercises) {
          final muscle = (ex as Map<String, dynamic>)['muscleGroup']
              .toString()
              .toLowerCase();
          expect(
            muscle.contains('chest') ||
                muscle.contains('shoulder') ||
                muscle.contains('tricep') ||
                muscle.contains('deltoid'),
            isTrue,
          );
        }
      },
    );

    testWidgets(
      '9. WorkoutSessionScreen initializes dynamically with matching exercises',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: WorkoutSessionScreen(
              workoutName: 'Upper Push Power & Chest Builder',
              workoutId: 'upper_push_01',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify that the screen loaded without falling back to squats
        expect(find.text('Barbell Back Squat'), findsNothing);
        expect(find.byType(WorkoutSessionScreen), findsOneWidget);
      },
    );

    testWidgets(
      '10. WorkoutSessionScreen renders safely on 320px, 360px, 390px, and 412px viewports',
      (tester) async {
        final viewports = [
          const Size(320, 640),
          const Size(360, 780),
          const Size(390, 844),
          const Size(412, 915),
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const MaterialApp(
              home: WorkoutSessionScreen(
                workoutName: 'Lower Body Strength',
                workoutId: 'lower_body_01',
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow exception at $size',
          );
        }

        tester.view.resetPhysicalSize();
        tester.view.devicePixelRatio = 1.0;
      },
    );

    test(
      '11. Canonical Exercise Database Completeness: all exercises contain complete metadata',
      () {
        final registry = Exercise.defaultRegistry();
        expect(registry.length, greaterThanOrEqualTo(30));

        final seenIds = <String>{};
        for (final ex in registry) {
          expect(ex.id, isNotEmpty, reason: 'Exercise ID must not be empty');
          expect(
            ex.name,
            isNotEmpty,
            reason: 'Exercise name must not be empty',
          );
          expect(
            ex.category,
            isNotEmpty,
            reason: 'Category must not be empty for ${ex.name}',
          );
          expect(
            ex.primaryMuscles,
            isNotEmpty,
            reason: 'primaryMuscles must not be empty for ${ex.name}',
          );
          expect(
            ex.instructions,
            isNotEmpty,
            reason: 'instructions must not be empty for ${ex.name}',
          );
          expect(
            ex.coachingTips,
            isNotEmpty,
            reason: 'coachingTips must not be empty for ${ex.name}',
          );
          expect(
            ex.commonMistakes,
            isNotEmpty,
            reason: 'commonMistakes must not be empty for ${ex.name}',
          );
          expect(
            ex.alternatives,
            isNotEmpty,
            reason: 'alternatives must not be empty for ${ex.name}',
          );
          expect(
            ex.imageUrl,
            isNotNull,
            reason: 'imageUrl must not be null for ${ex.name}',
          );
          expect(
            ex.imageUrl!.startsWith('assets/exercises/') ||
                ex.imageUrl!.startsWith('https://'),
            isTrue,
            reason:
                'imageUrl must follow canonical asset pattern or verified URL for ${ex.name}',
          );
          expect(ex.imageAsset, equals(ex.animationAsset ?? ex.imageUrl));

          // Verify ID uniqueness
          expect(
            seenIds.contains(ex.id),
            isFalse,
            reason: 'Duplicate exercise ID found: ${ex.id}',
          );
          seenIds.add(ex.id);
        }
      },
    );

    test(
      '12. Alternative Exercise ID Referencing Integrity: all alternatives point to existing registry exercises',
      () {
        final registry = Exercise.defaultRegistry();
        final validIds = registry.map((e) => e.id).toSet();

        for (final ex in registry) {
          for (final altId in ex.alternatives) {
            expect(
              validIds.contains(altId),
              isTrue,
              reason:
                  'Exercise "${ex.name}" (${ex.id}) references unknown alternative ID: "$altId"',
            );
          }

          // Test Exercise.getAlternatives helper
          final resolvedAlts = Exercise.getAlternatives(ex);
          expect(resolvedAlts.length, equals(ex.alternatives.length));
          for (final alt in resolvedAlts) {
            expect(alt.name, isNotEmpty);
            expect(alt.id, isNot(equals(ex.id)));
          }
        }
      },
    );

    test(
      '13. Lookup and search robustness: getById and findByName handle casing, spaces, and hyphens',
      () {
        expect(Exercise.getById('bench_press'), isNotNull);
        expect(Exercise.getById('BENCH_PRESS'), isNotNull);
        expect(Exercise.getById('bench-press'), isNotNull);
        expect(Exercise.getById('barbell_back_squat'), isNotNull);

        expect(Exercise.findByName('Barbell Bench Press'), isNotNull);
        expect(Exercise.findByName('barbell bench press'), isNotNull);
        expect(Exercise.findByName('bench_press'), isNotNull);
        expect(Exercise.findByName('NonExistentExercise123'), isNull);
      },
    );

    test('14. Canonical Exercise model JSON serialization and aliases', () {
      final ex = Exercise.getById('bench_press')!;
      final json = ex.toJson();

      expect(json['exerciseId'], equals('bench_press'));
      expect(json['imageAsset'], equals(ex.imageAsset));
      expect(json['muscleGroups'], isA<List>());
      expect(json['coachingTips'], isA<List>());

      final deserialized = Exercise.fromJson(json);
      expect(deserialized.exerciseId, equals('bench_press'));
      expect(deserialized.name, equals('Barbell Bench Press'));
      expect(
        deserialized.imageAsset,
        equals(ex.imageAsset),
      );
      expect(deserialized.coachingTips, isNotEmpty);
    });
  });
}
