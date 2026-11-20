import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:atlas/ai_form_coach/models/form_feedback.dart';
import 'package:atlas/ai_form_coach/models/pose_landmark.dart';
import 'package:atlas/ai_form_coach/services/video_processing_service.dart';
import 'package:atlas/ai_form_coach/widgets/form_score_widget.dart';
import 'package:atlas/ai_form_coach/widgets/feedback_card.dart';
import 'package:atlas/ai_form_coach/widgets/skeleton_overlay.dart';
import 'package:atlas/ai_form_coach/screens/ai_form_coach_screen.dart';

void main() {
  group('AI Form Coach — Phase 1: Widget & Screen Tests', () {
    testWidgets('FormScoreWidget displays score and grade text correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FormScoreWidget(score: 92))),
      );

      expect(find.text('92'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('ELITE FORM'), findsOneWidget);
    });

    testWidgets('FeedbackCard renders mistakes and coaching cues cleanly', (
      tester,
    ) async {
      final feedback = FormFeedback(
        score: 65,
        warnings: ['Knee valgus detected on ascent.'],
        corrections: ['Push knees outward in line with toes.'],
        positiveFeedback: ['Good vertical torso.'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedbackCard(feedback: feedback)),
        ),
      );

      expect(find.text('FORM CORRECTIONS NEEDED'), findsOneWidget);
      expect(find.text('Knee valgus detected on ascent.'), findsOneWidget);
      expect(
        find.text('Push knees outward in line with toes.'),
        findsOneWidget,
      );
      expect(find.text('Good vertical torso.'), findsOneWidget);
    });

    testWidgets('SkeletonOverlay renders custom painter without errors', (
      tester,
    ) async {
      final landmarks = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.4,
          y: 0.3,
          z: 0,
          confidence: 0.9,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightShoulder,
          x: 0.6,
          y: 0.3,
          z: 0,
          confidence: 0.9,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.45,
          y: 0.6,
          z: 0,
          confidence: 0.9,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightHip,
          x: 0.55,
          y: 0.6,
          z: 0,
          confidence: 0.9,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: SkeletonOverlay(landmarks: landmarks, isGoodForm: true),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonOverlay), findsOneWidget);
    });

    testWidgets(
      'AIFormCoachScreen loads with exercise selector and action buttons',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: AIFormCoachScreen(initialExercise: 'Squat')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Squat'), findsAtLeastNWidgets(1));
        expect(find.text('REPS COUNT'), findsOneWidget);
        expect(find.text('FORM SCORE'), findsOneWidget);
        expect(find.text('Record Video'), findsOneWidget);
        expect(find.text('Upload Video'), findsOneWidget);
        expect(find.byType(SkeletonOverlay), findsOneWidget);
      },
    );

    testWidgets('AIFormCoachScreen switches between supported MVP exercises', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AIFormCoachScreen(initialExercise: 'Squat')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap dropdown to open options
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      // Check that other MVP exercises are in the dropdown
      expect(find.text('Bench Press'), findsAtLeastNWidgets(1));
      expect(find.text('Bicep Curl'), findsAtLeastNWidgets(1));
      expect(find.text('Push-up'), findsAtLeastNWidgets(1));
      expect(find.text('Deadlift'), findsAtLeastNWidgets(1));

      // Select Bench Press
      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'AIFormCoachScreen handles video cancellation gracefully with SnackBar',
      (tester) async {
        VideoProcessingService.instance.videoPickerOverride = () async => null;

        await tester.pumpWidget(
          const MaterialApp(home: AIFormCoachScreen(initialExercise: 'Squat')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Upload Video
        await tester.tap(find.text('Upload Video'));
        await tester.pumpAndSettle();

        // In test environment without selection, SnackBar appears
        expect(find.text('No video was selected.'), findsOneWidget);
        VideoProcessingService.instance.videoPickerOverride = null;
      },
    );

    testWidgets(
      'AIFormCoachScreen displays error dialog when video file is not found',
      (tester) async {
        VideoProcessingService.instance.videoPickerOverride =
            () async => XFile('non_existent_clip.mp4');

        await tester.pumpWidget(
          const MaterialApp(home: AIFormCoachScreen(initialExercise: 'Squat')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Upload Video
        await tester.tap(find.text('Upload Video'));
        await tester.pumpAndSettle();

        // Error dialog appears with friendly message and retry options
        expect(find.text('Video Analysis Notice'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        expect(find.text('Video Analysis Notice'), findsNothing);
        VideoProcessingService.instance.videoPickerOverride = null;
      },
    );
  });
}
