import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/ai_form_coach/models/pose_landmark.dart';
import 'package:atlas/ai_form_coach/models/form_feedback.dart';
import 'package:atlas/ai_form_coach/models/exercise_analysis.dart';

void main() {
  group('AI Form Coach — Phase 1: Models & Math Tests', () {
    test('PoseLandmark stores 3D coordinates and visibility', () {
      final landmark = PoseLandmark(
        name: PoseLandmarkNames.leftKnee,
        x: 0.52,
        y: 0.74,
        z: 0.05,
        confidence: 0.98,
      );

      expect(landmark.name, 'left_knee');
      expect(landmark.x, 0.52);
      expect(landmark.y, 0.74);
      expect(landmark.z, 0.05);
      expect(landmark.confidence, 0.98);
      expect(landmark.visibility, 0.98);
    });

    test('PoseLandmark.calculateAngle calculates right angle (90 degrees)', () {
      // Vertex at origin (0, 0)
      // A at (0, 1) -> straight up
      // B at (0, 0) -> vertex
      // C at (1, 0) -> straight right
      final a = PoseLandmark(
        name: 'A',
        x: 0.0,
        y: 1.0,
        z: 0.0,
        confidence: 1.0,
      );
      final b = PoseLandmark(
        name: 'B',
        x: 0.0,
        y: 0.0,
        z: 0.0,
        confidence: 1.0,
      );
      final c = PoseLandmark(
        name: 'C',
        x: 1.0,
        y: 0.0,
        z: 0.0,
        confidence: 1.0,
      );

      final angle = PoseLandmark.calculateAngle(a, b, c);
      expect(angle, isNotNull);
      expect(angle!, closeTo(90.0, 0.01));
    });

    test(
      'PoseLandmark.calculateAngle calculates straight line (180 degrees)',
      () {
        final a = PoseLandmark(
          name: 'A',
          x: 0.0,
          y: 1.0,
          z: 0.0,
          confidence: 1.0,
        );
        final b = PoseLandmark(
          name: 'B',
          x: 0.0,
          y: 0.0,
          z: 0.0,
          confidence: 1.0,
        );
        final c = PoseLandmark(
          name: 'C',
          x: 0.0,
          y: -1.0,
          z: 0.0,
          confidence: 1.0,
        );

        final angle = PoseLandmark.calculateAngle(a, b, c);
        expect(angle, isNotNull);
        expect(angle!, closeTo(180.0, 0.01));
      },
    );

    test(
      'PoseLandmark.calculateAngle returns null if confidence is below threshold',
      () {
        final a = PoseLandmark(
          name: 'A',
          x: 0.0,
          y: 1.0,
          z: 0.0,
          confidence: 0.2,
        );
        final b = PoseLandmark(
          name: 'B',
          x: 0.0,
          y: 0.0,
          z: 0.0,
          confidence: 1.0,
        );
        final c = PoseLandmark(
          name: 'C',
          x: 1.0,
          y: 0.0,
          z: 0.0,
          confidence: 1.0,
        );

        final angle = PoseLandmark.calculateAngle(a, b, c, minConfidence: 0.5);
        expect(angle, isNull);
      },
    );

    test('PoseLandmark json serialization roundtrip', () {
      final original = PoseLandmark(
        name: 'left_elbow',
        x: 0.45,
        y: 0.38,
        z: -0.02,
        confidence: 0.92,
      );

      final json = original.toJson();
      final reconstructed = PoseLandmark.fromJson(json);

      expect(reconstructed.name, original.name);
      expect(reconstructed.x, original.x);
      expect(reconstructed.y, original.y);
      expect(reconstructed.z, original.z);
      expect(reconstructed.confidence, original.confidence);
    });

    test('FormFeedback handles scoring thresholds and grade labels', () {
      final elite = FormFeedback(
        score: 95,
        warnings: [],
        corrections: [],
        positiveFeedback: ['Pristine form.'],
      );
      expect(elite.isGoodForm, isTrue);
      expect(elite.hasWarnings, isFalse);
      expect(elite.gradeLabel, 'Elite Form');

      final warning = FormFeedback(
        score: 60,
        warnings: ['Hips sagging.'],
        corrections: ['Brace core.'],
      );
      expect(warning.isGoodForm, isFalse);
      expect(warning.hasWarnings, isTrue);
      expect(warning.gradeLabel, 'Action Needed');
    });

    test('ExerciseAnalysis encapsulates session data and serialization', () {
      final feedback = FormFeedback(
        score: 88,
        warnings: ['Slight knee wobble.'],
        corrections: ['Push knees out.'],
      );

      final analysis = ExerciseAnalysis(
        exerciseName: 'Squat',
        feedback: feedback,
        repCount: 8,
        detectedMistakes: ['Slight knee wobble.'],
        corrections: ['Push knees out.'],
        jointAngles: {'kneeDepth': 92.5},
        metrics: {'durationSeconds': 24},
      );

      expect(analysis.exerciseName, 'Squat');
      expect(analysis.formScore, 88);
      expect(analysis.repCount, 8);
      expect(analysis.detectedMistakes, contains('Slight knee wobble.'));

      final json = analysis.toJson();
      final roundtrip = ExerciseAnalysis.fromJson(json);

      expect(roundtrip.exerciseName, 'Squat');
      expect(roundtrip.formScore, 88);
      expect(roundtrip.repCount, 8);
    });

    test(
      'PoseLandmark.fromMlKit extracts 3D coordinates, converts joint name, and normalizes',
      () {
        // Mock object matching ML Kit landmark shape
        final mockMlKitLandmark = _MockMlKitLandmark(
          type: _MockPoseLandmarkType.leftShoulder,
          x: 480.0,
          y: 640.0,
          z: -15.0,
          likelihood: 0.96,
        );

        final landmark = PoseLandmark.fromMlKit(
          mockMlKitLandmark,
          imageWidth: 1000.0,
          imageHeight: 1000.0,
        );

        expect(landmark.name, 'left_shoulder');
        expect(landmark.x, closeTo(0.48, 0.001));
        expect(landmark.y, closeTo(0.64, 0.001));
        expect(landmark.z, -15.0);
        expect(landmark.confidence, 0.96);
      },
    );

    test('FormFeedback handles confidence percentage calculation', () {
      final feedback = FormFeedback(
        score: 92,
        confidence: 0.887,
        warnings: [],
        corrections: [],
      );

      expect(feedback.confidence, 0.887);
      expect(feedback.confidencePercentage, 89);
    });
  });
}

enum _MockPoseLandmarkType { leftShoulder }

class _MockMlKitLandmark {
  final _MockPoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  _MockMlKitLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });
}
