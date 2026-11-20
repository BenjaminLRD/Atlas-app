import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/widgets/media/video_playback.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise_media_service.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/screens/exercise_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exercise Media Architecture & Model Integrity', () {
    test(
      '1. Exercise model supports all required canonical fields and aliases',
      () {
        const exercise = Exercise(
          id: 'hiit_cycling',
          name: 'HIIT Bike Sprints',
          category: 'cardio',
          primaryMuscles: ['Quadriceps', 'Glutes'],
          secondaryMuscles: ['Calves', 'Cardiovascular'],
          equipment: 'Air Bike / Spin Bike',
          difficulty: 'Advanced',
          movementPattern: 'cardio',
          exerciseType: 'hiit',
          instructions: [
            'Adjust saddle height to hip level.',
            'Sprint at maximum cadence for 20 seconds.',
            'Recover at slow pace for 40 seconds.',
          ],
          tips: [
            'Maintain upright torso.',
            'Drive through both pedals with equal power.',
          ],
          commonMistakes: [
            'Slouching or collapsing over handlebars.',
            'Starting recovery interval too late.',
          ],
          alternatives: ['rowing_intervals', 'sprint_intervals'],
          imageUrl: 'https://example.com/bike.jpg',
          videoUrl: 'https://example.com/bike.mp4',
          durationSeconds: 45,
        );

        expect(exercise.id, equals('hiit_cycling'));
        expect(exercise.exerciseId, equals('hiit_cycling'));
        expect(exercise.name, equals('HIIT Bike Sprints'));
        expect(exercise.targetMuscles, contains('Quadriceps'));
        expect(exercise.targetMuscles, contains('Glutes'));
        expect(exercise.equipment, equals('Air Bike / Spin Bike'));
        expect(exercise.difficulty, equals('Advanced'));
        expect(exercise.instructions.length, equals(3));
        expect(exercise.commonMistakes.length, equals(2));
        expect(exercise.videoAsset, equals('https://example.com/bike.mp4'));
        expect(exercise.imageAsset, equals('https://example.com/bike.jpg'));
        expect(exercise.coachingTips.length, equals(2));
      },
    );

    test(
      '2. CategoryIcon resolves context-appropriate icons for varied exercise types',
      () {
        final benchPress = Exercise.getById('bench_press')!;
        final pullUps = Exercise.getById('pull_ups')!;
        final hiitBike = Exercise.getById('hiit_cycling')!;
        final run = Exercise.getById('outdoor_run')!;
        final plank = Exercise.getById('plank')!;
        final stretch = Exercise.getById('cat_cow_stretch')!;

        // Strength / Chest
        expect(benchPress.categoryIcon, equals(Icons.fitness_center_rounded));
        // Bodyweight / Pull
        expect(pullUps.categoryIcon, isNotNull);
        // HIIT Bike Sprints — MUST resolve cycling/bike icon
        expect(hiitBike.categoryIcon, equals(Icons.directions_bike_rounded));
        // Running
        expect(run.categoryIcon, equals(Icons.directions_run_rounded));
        // Core / Plank
        expect(plank.categoryIcon, equals(Icons.timer_outlined));
        // Mobility
        expect(stretch.categoryIcon, equals(Icons.self_improvement_rounded));
      },
    );

    test('3. ExerciseMediaService resolves media priority chain correctly', () {
      final service = ExerciseMediaService();
      service.clearCache();

      // Case A: Has video -> Video
      const exVideo = Exercise(
        id: 'ex_vid',
        name: 'Video Exercise',
        videoUrl: 'https://cdn.example.com/demo.mp4',
        imageUrl: 'https://cdn.example.com/thumb.jpg',
      );
      final mediaVid = service.resolveMedia(exVideo);
      expect(mediaVid.mediaType, equals('video'));
      expect(mediaVid.url, equals('https://cdn.example.com/demo.mp4'));
      expect(mediaVid.thumbnail, equals('https://cdn.example.com/thumb.jpg'));

      // Case B: Has animation, no video -> GIF / Animation
      const exAnim = Exercise(
        id: 'ex_anim',
        name: 'Animation Exercise',
        animationAsset: 'assets/exercises/anim.gif',
      );
      final mediaAnim = service.resolveMedia(exAnim);
      expect(mediaAnim.mediaType, equals('gif'));
      expect(mediaAnim.url, equals('assets/exercises/anim.gif'));

      // Case C: Has image only -> Image
      const exImg = Exercise(
        id: 'ex_img',
        name: 'Image Exercise',
        imageUrl: 'https://cdn.example.com/photo.png',
      );
      final mediaImg = service.resolveMedia(exImg);
      expect(mediaImg.mediaType, equals('image'));
      expect(mediaImg.url, equals('https://cdn.example.com/photo.png'));

      // Case D: No media -> Intentional placeholder
      const exNone = Exercise(id: 'ex_none', name: 'No Media Exercise');
      final mediaNone = service.resolveMedia(exNone);
      expect(mediaNone.mediaType, equals('placeholder'));
      expect(service.hasMedia(exNone), isFalse);
    });

    test(
      '4. JSON serialization roundtrip preserves targetMuscles and videoAsset',
      () {
        const exercise = Exercise(
          id: 'custom_pushup',
          name: 'Custom Pushup',
          primaryMuscles: ['Chest', 'Triceps'],
          videoUrl: 'https://example.com/video.mp4',
          imageUrl: 'https://example.com/image.jpg',
        );

        final json = exercise.toJson();
        expect(json['targetMuscles'], contains('Chest'));
        expect(json['videoAsset'], equals('https://example.com/video.mp4'));

        final restored = Exercise.fromJson(json);
        expect(restored.targetMuscles, contains('Chest'));
        expect(restored.videoAsset, equals('https://example.com/video.mp4'));
      },
    );
  });

  group('Exercise Form Guide UI & Video Player Tests', () {
    testWidgets(
      '5. Form Guide renders Strength exercise (Barbell Bench Press)',
      (tester) async {
        final exercise = Exercise.getById('bench_press')!;

        await tester.pumpWidget(
          MaterialApp(
            home: ExerciseDetailScreen(
              exercise: exercise,
              enableWorkoutStart: false,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Barbell Bench Press'), findsAtLeastNWidgets(1));
        expect(find.text('How To Perform'), findsOneWidget);
        expect(find.text('Common Mistakes To Avoid'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Form Guide renders Machine exercise (Machine Chest Press)',
      (tester) async {
        final exercise = Exercise.getById('chest_press_machine')!;

        await tester.pumpWidget(
          MaterialApp(
            home: ExerciseDetailScreen(
              exercise: exercise,
              enableWorkoutStart: false,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Machine Chest Press'), findsAtLeastNWidgets(1));
        expect(find.text('How To Perform'), findsOneWidget);
        // Drawn demonstration first; the stock clip stays one tap away.
        expect(find.text('FORM ANIMATION'), findsOneWidget);
      },
    );

    testWidgets('7. Form Guide renders Bodyweight exercise (Pull-ups)', (
      tester,
    ) async {
      final exercise = Exercise.getById('pull_ups')!;

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseDetailScreen(
            exercise: exercise,
            enableWorkoutStart: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pull-ups'), findsAtLeastNWidgets(1));
      expect(find.text('How To Perform'), findsOneWidget);
    });

    testWidgets('8. Form Guide renders Cardio exercise (Outdoor Run)', (
      tester,
    ) async {
      final exercise = Exercise.getById('outdoor_run')!;

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseDetailScreen(
            exercise: exercise,
            enableWorkoutStart: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Outdoor Run'), findsAtLeastNWidgets(1));
      expect(find.text('FORM ANIMATION'), findsOneWidget);
      expect(find.text('How To Perform'), findsOneWidget);
    });

    testWidgets(
      '9. Form Guide renders HIIT Bike Sprints with cycling icon and visual guide state',
      (tester) async {
        final exercise = Exercise.getById('hiit_cycling')!;

        await tester.pumpWidget(
          MaterialApp(
            home: ExerciseDetailScreen(
              exercise: exercise,
              enableWorkoutStart: false,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('HIIT Bike Sprints'), findsAtLeastNWidgets(1));
        expect(find.text('FORM ANIMATION'), findsOneWidget);
        expect(find.text('How To Perform'), findsOneWidget);
        expect(find.text('Common Mistakes To Avoid'), findsOneWidget);
      },
    );

    testWidgets(
      '10. ExerciseVideoPlayer opens the verified YouTube video on request',
      (tester) async {
        final exercise = Exercise.getById('swimming')!;
        final opened = <Uri>[];
        final prev = ExerciseVideoPlayer.launcher;
        addTearDown(() => ExerciseVideoPlayer.launcher = prev);
        ExerciseVideoPlayer.launcher = (uri) async {
          opened.add(uri);
          return true;
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExerciseVideoPlayer(
                exercise: exercise,
                autoPlay: false,
                showControls: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('YOUTUBE DEMO'), findsOneWidget);
        final playBtn = find.byKey(const Key('exercise_video_play'));
        expect(playBtn, findsOneWidget);

        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 100));

        // Nothing is embedded: the video opens in YouTube itself.
        expect(find.byType(VideoPlayback), findsNothing);
        expect(opened.length, 1);
        expect(opened.single.host, 'www.youtube.com');
      },
    );

    testWidgets('11. Fullscreen toggle opens fullscreen dialog cleanly', (
      tester,
    ) async {
      final exercise = Exercise.getById('hiit_cycling')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseVideoPlayer(exercise: exercise, showControls: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenBtn, findsOneWidget);

      await tester.tap(fullscreenBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog opens with close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets(
      '12. ExerciseLibraryScreen renders list with category-aware thumbnails',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ExerciseLibraryScreen()),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Exercise Library'), findsOneWidget);
        expect(find.text('Barbell Bench Press'), findsOneWidget);
      },
    );
  });
}
