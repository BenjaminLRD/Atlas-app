import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/exercise_media.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/exercise_media_service.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/screens/exercise_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & 9 — Exercise & ExerciseMedia Data Models', () {
    test(
      'Exercise model initializes with guidance fields and coachingTips alias',
      () {
        final exercise = Exercise(
          id: 'barbell_squat',
          name: 'Barbell Back Squat',
          muscleGroup: 'Quadriceps, Glutes',
          equipment: 'Barbell & Rack',
          difficulty: 'Advanced',
          durationSeconds: 45,
          videoUrl: 'https://example.com/squat.mp4',
          animationAsset: 'assets/exercises/squat.png',
          instructions: [
            'Place bar on upper back',
            'Brace core',
            'Lower under control',
          ],
          commonMistakes: ['Knees collapsing inward', 'Rounded lower spine'],
          coachingTips: ['Drive through heels', 'Keep chest proud'],
        );

        expect(exercise.id, 'barbell_squat');
        expect(exercise.durationSeconds, 45);
        expect(exercise.videoUrl, 'https://example.com/squat.mp4');
        expect(exercise.animationAsset, 'assets/exercises/squat.png');
        expect(exercise.instructions.length, 3);
        expect(exercise.commonMistakes.length, 2);
        expect(exercise.tips.length, 2);
        expect(exercise.coachingTips, exercise.tips);
      },
    );

    test('Exercise JSON serialization round-trip maintains all fields', () {
      final original = Exercise(
        id: 'romanian_deadlift',
        name: 'Romanian Deadlift',
        muscleGroup: 'Hamstrings, Glutes',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Intermediate',
        durationSeconds: 40,
        videoUrl: 'https://example.com/rdl.mp4',
        animationAsset: 'assets/exercises/rdl.png',
        instructions: ['Hinge at hips', 'Lower with neutral spine'],
        tips: ['Soft knee bend', 'Push glutes back'],
        commonMistakes: ['Rounding back'],
        alternatives: ['dumbbell_rdl'],
      );

      final json = original.toJson();
      final deserialized = Exercise.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.durationSeconds, 40);
      expect(deserialized.videoUrl, original.videoUrl);
      expect(deserialized.animationAsset, original.animationAsset);
      expect(deserialized.instructions, original.instructions);
      expect(deserialized.tips, original.tips);
      expect(deserialized.commonMistakes, original.commonMistakes);
      expect(deserialized.alternatives, original.alternatives);
    });

    test('ExerciseMedia model serializes for Supabase storage', () {
      final now = DateTime(2026, 8, 15, 12, 0);
      final media = ExerciseMedia(
        id: 'media_01',
        exerciseId: 'barbell_squat',
        mediaType: 'video',
        url: 'https://storage.supabase.co/exercises/squat.mp4',
        thumbnail: 'https://storage.supabase.co/exercises/squat_thumb.png',
        createdAt: now,
      );

      final map = media.toMap();
      expect(map['id'], 'media_01');
      expect(map['exercise_id'], 'barbell_squat');
      expect(map['media_type'], 'video');
      expect(map['url'], contains('squat.mp4'));

      final fromMap = ExerciseMedia.fromMap(map);
      expect(fromMap.id, media.id);
      expect(fromMap.exerciseId, media.exerciseId);
      expect(fromMap.mediaType, media.mediaType);
      expect(fromMap.thumbnail, media.thumbnail);
    });
  });

  group('Phase 2 — ExerciseMediaService Fallbacks', () {
    late ExerciseMediaService mediaService;

    setUp(() {
      mediaService = ExerciseMediaService();
      mediaService.clearCache();
    });

    test('Resolves video media when videoUrl is present', () {
      const ex = Exercise(
        id: 'squat',
        name: 'Squat',
        muscleGroup: 'Legs',
        equipment: 'Barbell',
        videoUrl: 'https://example.com/squat.mp4',
      );

      expect(
        mediaService.getExerciseVideo(ex),
        'https://example.com/squat.mp4',
      );
      expect(mediaService.hasMedia(ex), isTrue);

      final media = mediaService.resolveMedia(ex);
      expect(media.mediaType, 'video');
      expect(media.url, 'https://example.com/squat.mp4');
    });

    test('Falls back to animation asset when video is absent', () {
      const ex = Exercise(
        id: 'push_up',
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
        animationAsset: 'assets/exercises/push_up.png',
      );

      expect(mediaService.getExerciseVideo(ex), isNull);
      expect(mediaService.getAnimation(ex), 'assets/exercises/push_up.png');
      expect(mediaService.hasMedia(ex), isTrue);

      final media = mediaService.resolveMedia(ex);
      expect(media.mediaType, 'gif');
      expect(media.url, 'assets/exercises/push_up.png');
    });

    test('Falls back to placeholder when no media exists', () {
      const ex = Exercise(
        id: 'unknown_movement',
        name: 'Unknown Movement',
        muscleGroup: 'Core',
        equipment: 'None',
      );

      expect(mediaService.getExerciseVideo(ex), isNull);
      expect(mediaService.hasMedia(ex), isFalse);

      final media = mediaService.resolveMedia(ex);
      expect(media.mediaType, 'placeholder');
    });
  });

  group('Phase 4 & 5 — ExerciseVideoPlayer Widget', () {
    testWidgets('Renders video player with controls', (tester) async {
      // Swimming has a verified YouTube demonstration and no animation, so
      // the player opens straight on the video panel.
      final exercise = Exercise.getById('swimming')!;

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

      expect(find.text('YOUTUBE DEMO'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('Renders fallback badge when no video or animation exists', (
      tester,
    ) async {
      const exercise = Exercise(
        id: 'unpopulated_exercise',
        name: 'Custom Core Drill',
        muscleGroup: 'Core',
        equipment: 'Bodyweight',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseVideoPlayer(
              exercise: exercise,
              autoPlay: false,
              showControls: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('no_demonstration')), findsOneWidget);
      expect(find.text('VISUAL CUES'), findsOneWidget);
    });
  });

  group('Phase 3 & 10 — ExerciseDetailScreen & Multi-Device Matrix', () {
    const testExercise = Exercise(
      id: 'barbell_back_squat',
      name: 'Barbell Back Squat',
      muscleGroup: 'Quadriceps, Glutes',
      equipment: 'Barbell & Rack',
      difficulty: 'Advanced',
      durationSeconds: 45,
      videoUrl: 'https://example.com/squat.mp4',
      instructions: [
        'Rest bar across upper trapezius muscles',
        'Brace core tight and inhale',
        'Lower until thighs are parallel to floor',
        'Drive through heels to stand',
      ],
      commonMistakes: ['Knees collapsing inward', 'Lower back rounding'],
      tips: ['Keep chest upright', 'Maintain knee tracking over toes'],
      alternatives: ['dumbbell_goblet_squat', 'leg_press'],
    );

    for (final size in const [
      Size(320, 640),
      Size(360, 780),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets('Renders without overflow on ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: ExerciseDetailScreen(
              exercise: testExercise,
              enableWorkoutStart: true,
            ),
          ),
        );
        // The form animation loops forever, so wait a moment instead of
        // waiting for the screen to settle.
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Exercise Form Guide'), findsOneWidget);
        expect(find.text('Barbell Back Squat'), findsAtLeastNWidgets(1));
        expect(find.text('ADVANCED'), findsOneWidget);
        expect(find.text('How To Perform'), findsOneWidget);
        expect(find.text('Common Mistakes To Avoid'), findsOneWidget);
        expect(find.text('AI Coach Form Cues'), findsOneWidget);
        expect(find.text('Start Exercise In Workout'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Toggles favorite state with feedback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExerciseDetailScreen(
            exercise: testExercise,
            enableWorkoutStart: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final favoriteBtn = find.byIcon(Icons.favorite_border_rounded);
      await tester.tap(favoriteBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(
        find.text('Barbell Back Squat added to favorites!'),
        findsOneWidget,
      );
    });
  });

  group('Phase 6 — ExerciseLibraryScreen & Filtering', () {
    testWidgets('Filters exercises by search query', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Exercise Library'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Search for bench
      await tester.enterText(find.byType(TextField), 'bench');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Bench'), findsAtLeastNWidgets(1));
      expect(find.text('Barbell Back Squat'), findsNothing);
    });

    testWidgets('Filters exercises by difficulty chip', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Advanced difficulty chip
      final advancedChip = find.widgetWithText(ChoiceChip, 'Advanced');
      expect(advancedChip, findsOneWidget);

      await tester.tap(advancedChip);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Barbell Back Squat'), findsOneWidget);
    });
  });

  group('Phase 8 — AI Coach Form Guidance Integration', () {
    test(
      'MockAIProvider responds to exercise form questions using guidance cues',
      () async {
        const provider = MockAIProvider();
        final dummyContext = FitnessContext.initial();

        final response = await provider.generateResponse(
          message: 'How do I improve my squat technique and form?',
          context: dummyContext,
          history: [],
        );

        expect(response, contains('Barbell Back Squat'));
        expect(response, contains('Common Issues'));
        expect(response, contains('Coaching Tips'));
        expect(response, contains('Exercise Library'));
      },
    );
  });
}
