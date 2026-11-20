import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise_media_service.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = Exercise.defaultRegistry();

  group('Phase 2.5 — Complete Exercise Media Quality Audit', () {
    test(
      '1. Inventory Audit: Exactly 72 exercises in defaultRegistry with valid HTTPS media',
      () {
        expect(registry.length, 72);

        for (final exercise in registry) {
          // Exercise identification
          expect(
            exercise.id,
            isNotEmpty,
            reason: 'Exercise ID must not be empty',
          );
          expect(
            exercise.name,
            isNotEmpty,
            reason: 'Exercise name must not be empty',
          );
          expect(
            exercise.category,
            isNotEmpty,
            reason: 'Category must not be empty',
          );
          expect(
            exercise.movementPattern,
            isNotEmpty,
            reason: 'Movement pattern required for AI Form Coach',
          );
          expect(
            exercise.equipment,
            isNotEmpty,
            reason: 'Equipment must not be empty',
          );
          expect(
            exercise.instructions,
            isNotEmpty,
            reason: 'Instructions must not be empty',
          );
          expect(
            exercise.commonMistakes,
            isNotEmpty,
            reason: 'Common mistakes must not be empty',
          );

          // Media reference validation
          final hasMedia = ExerciseMediaService().hasMedia(exercise);
          expect(
            hasMedia,
            isTrue,
            reason:
                'Exercise ${exercise.name} (${exercise.id}) must have media',
          );

          final media = exercise.media;
          expect(
            media.url,
            isNotEmpty,
            reason: 'Media URL for ${exercise.name} must not be empty',
          );
          expect(
            media.url.startsWith('https://'),
            isTrue,
            reason: 'Media URL must use secure HTTPS',
          );
          expect(
            ['video', 'gif', 'image', 'placeholder'].contains(media.mediaType),
            isTrue,
            reason: 'Media type must be one of the standard supported types',
          );
        }
      },
    );

    test(
      '2. Accuracy & Category Alignment Audit across all 8 movement clusters',
      () {
        final map = {for (final e in registry) e.id: e};

        // Chest & Push (9)
        expect(map['bench_press']!.media.mediaType, 'video');
        expect(map['incline_bench_press']!.media.mediaType, 'video');
        expect(map['dumbbell_bench_press']!.media.mediaType, 'video');
        expect(map['incline_dumbbell_press']!.media.mediaType, 'video');
        expect(map['chest_press_machine']!.media.mediaType, 'video');
        expect(map['cable_chest_fly']!.media.mediaType, 'image');
        expect(map['dumbbell_chest_fly']!.media.mediaType, 'gif');
        expect(map['chest_dips']!.media.mediaType, 'gif');
        expect(map['push_ups']!.media.mediaType, 'gif');

        // Shoulders (7)
        expect(map['overhead_press']!.media.mediaType, 'video');
        expect(map['dumbbell_shoulder_press']!.media.mediaType, 'gif');
        expect(map['lateral_raise']!.media.mediaType, 'image');
        expect(map['cable_lateral_raise']!.media.mediaType, 'image');
        expect(map['rear_delt_fly']!.media.mediaType, 'image');
        expect(map['face_pulls']!.media.mediaType, 'image');
        expect(map['arnold_press']!.media.mediaType, 'image');

        // Back & Pull (8)
        expect(map['conventional_deadlift']!.media.mediaType, 'video');
        expect(map['romanian_deadlift']!.media.mediaType, 'image');
        expect(map['pull_ups']!.media.mediaType, 'video');
        expect(map['chin_ups']!.media.mediaType, 'image');
        expect(map['lat_pulldown']!.media.mediaType, 'video');
        expect(map['barbell_row']!.media.mediaType, 'video');
        expect(map['dumbbell_row']!.media.mediaType, 'image');
        expect(map['seated_cable_row']!.media.mediaType, 'image');

        // Legs (12)
        expect(map['barbell_back_squat']!.media.mediaType, 'video');
        expect(map['bodyweight_squat']!.media.mediaType, 'gif');
        expect(map['dumbbell_goblet_squat']!.media.mediaType, 'image');
        expect(map['dumbbell_rdl']!.media.mediaType, 'image');
        expect(map['leg_press']!.media.mediaType, 'video');
        expect(map['leg_extension']!.media.mediaType, 'video');
        expect(map['hamstring_curl']!.media.mediaType, 'video');
        expect(map['bulgarian_split_squat']!.media.mediaType, 'image');
        expect(map['standing_calf_raise']!.media.mediaType, 'gif');
        expect(map['seated_calf_raise']!.media.mediaType, 'gif');
        expect(map['calf_press_leg_press']!.media.mediaType, 'video');
        expect(map['walking_lunges']!.media.mediaType, 'gif');

        // Arms (11)
        expect(map['bicep_curl']!.media.mediaType, 'video');
        expect(map['barbell_bicep_curl']!.media.mediaType, 'video');
        expect(map['hammer_curl']!.media.mediaType, 'gif');
        expect(map['preacher_curl']!.media.mediaType, 'gif');
        expect(map['concentration_curl']!.media.mediaType, 'image');
        expect(map['incline_dumbbell_curl']!.media.mediaType, 'gif');
        expect(map['cable_bicep_curl']!.media.mediaType, 'gif');
        expect(map['tricep_pushdown']!.media.mediaType, 'gif');
        expect(map['skull_crushers']!.media.mediaType, 'image');
        expect(map['overhead_tricep_extension']!.media.mediaType, 'image');
        expect(map['tricep_kickbacks']!.media.mediaType, 'gif');

        // Core (2)
        expect(map['hanging_leg_raise']!.media.mediaType, 'image');
        expect(map['plank']!.media.mediaType, 'image');

        // Cardio & Sports (17)
        expect(map['outdoor_run']!.media.mediaType, 'image');
        expect(map['treadmill_run']!.media.mediaType, 'image');
        expect(map['sprint_intervals']!.media.mediaType, 'image');
        expect(map['jogging']!.media.mediaType, 'image');
        expect(map['stationary_bike']!.media.mediaType, 'image');
        expect(map['outdoor_cycling']!.media.mediaType, 'image');
        expect(map['hiit_cycling']!.media.mediaType, 'image');
        expect(map['rowing_machine']!.media.mediaType, 'image');
        expect(map['rowing_intervals']!.media.mediaType, 'image');
        expect(map['jump_rope']!.media.mediaType, 'image');
        expect(map['burpees']!.media.mediaType, 'image');
        expect(map['mountain_climbers']!.media.mediaType, 'image');
        expect(map['hiit_circuit']!.media.mediaType, 'image');
        expect(map['football']!.media.mediaType, 'image');
        expect(map['basketball']!.media.mediaType, 'image');
        expect(map['swimming']!.media.mediaType, 'image');
        expect(map['boxing']!.media.mediaType, 'image');

        // Mobility & Flexibility (6)
        expect(map['cat_cow_stretch']!.media.mediaType, 'image');
        expect(map['world_greatest_stretch']!.media.mediaType, 'image');
        expect(map['foam_rolling_full_body']!.media.mediaType, 'image');
        expect(map['doorway_chest_stretch']!.media.mediaType, 'gif');
        expect(map['hip_flexor_stretch']!.media.mediaType, 'gif');
        expect(map['couch_stretch']!.media.mediaType, 'gif');
      },
    );

    test('3. Media Priority Chain: Video -> GIF -> Image -> Fallback', () {
      final mediaService = ExerciseMediaService();

      const allTiers = Exercise(
        id: 'tier_test',
        name: 'Multi Tier Drill',
        category: 'chest',
        videoUrl: 'https://example.com/video.mp4',
        animationAsset: 'https://example.com/animation.gif',
        imageUrl: 'https://example.com/image.png',
      );
      expect(mediaService.resolveMedia(allTiers).mediaType, 'video');

      const gifAndImage = Exercise(
        id: 'tier_test_gif',
        name: 'GIF Drill',
        category: 'chest',
        animationAsset: 'https://example.com/animation.gif',
        imageUrl: 'https://example.com/image.png',
      );
      expect(mediaService.resolveMedia(gifAndImage).mediaType, 'gif');

      const imageOnly = Exercise(
        id: 'tier_test_img',
        name: 'Image Drill',
        category: 'chest',
        imageUrl: 'https://example.com/image.png',
      );
      expect(mediaService.resolveMedia(imageOnly).mediaType, 'image');

      const noMedia = Exercise(
        id: 'tier_test_none',
        name: 'None Drill',
        category: 'chest',
      );
      expect(mediaService.resolveMedia(noMedia).mediaType, 'placeholder');
    });

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets(
        '4. Responsive Viewport Audit: ExerciseDetailScreen renders cleanly at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final testExercise = Exercise.getById('bench_press')!;
          await tester.pumpWidget(
            MaterialApp(
              home: ExerciseDetailScreen(
                exercise: testExercise,
                enableWorkoutStart: true,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text(testExercise.name), findsOneWidget);
          expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
          expect(find.text('How To Perform'), findsOneWidget);
          expect(find.text('Start Exercise In Workout'), findsOneWidget);
        },
      );
    }

    testWidgets(
      '5. Fallback Audit: High-value checklist renders gracefully when media is missing',
      (tester) async {
        const fallbackEx = Exercise(
          id: 'custom_drill_fallback',
          name: 'Dynamic Warmup Circuit',
          category: 'mobility',
          primaryMuscles: ['Hip Flexors', 'Spine'],
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExerciseVideoPlayer(
                exercise: fallbackEx,
                autoPlay: false,
                showControls: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Dynamic Warmup Circuit'), findsOneWidget);
        expect(find.byKey(const Key('no_demonstration')), findsOneWidget);
        expect(
          find.text(
            'Atlas provides: ✓ Instructions  ✓ Muscles  ✓ Mistakes  ✓ Tips',
          ),
          findsOneWidget,
        );
      },
    );

    test('6. AI Form Coach contract readiness on Exercise model', () {
      for (final ex in registry) {
        expect(ex.exerciseId, ex.id);
        expect(ex.name, isNotEmpty);
        expect(ex.movementPattern, isNotEmpty);
        expect(ex.equipment, isNotEmpty);
        expect(ex.instructions, isNotEmpty);
        expect(ex.commonMistakes, isNotEmpty);
        expect(ex.media, isNotNull);
        expect(ex.coachingTips, ex.tips);
      }
    });
  });
}
