import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/exercise_form_report.dart';
import 'package:atlas/services/form_detection/pose_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('1. Pose Landmark Extraction & Kinematic Math Tests', () {
    test('Calculates joint angles accurately with vector dot product', () {
      final frame = PoseFrame(
        frameIndex: 0,
        timestampMs: 0.0,
        landmarks: {
          PoseLandmarkType.leftHip: const PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.0, y: 1.0),
          PoseLandmarkType.leftKnee: const PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0.0, y: 0.0),
          PoseLandmarkType.leftAnkle: const PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 1.0, y: 0.0),
        },
      );

      final angle = frame.getAngle(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      );

      expect(angle, isNotNull);
      expect(angle!.round(), equals(90));
    });

    test('Calculates vertical lean and Euclidean distance accurately', () {
      final frame = PoseFrame(
        frameIndex: 0,
        timestampMs: 0.0,
        landmarks: {
          PoseLandmarkType.leftShoulder: const PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.0, y: 0.0),
          PoseLandmarkType.leftHip: const PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.0, y: 1.0),
          PoseLandmarkType.leftAnkle: const PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 3.0, y: 4.0),
        },
      );

      final verticalAngle = frame.getVerticalAngle(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
      );
      expect(verticalAngle, isNotNull);
      expect(verticalAngle!.round(), equals(0)); // Perfectly vertical

      final distance = frame.getDistance(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftAnkle,
      );
      expect(distance, isNotNull);
      expect(distance, closeTo(5.0, 0.01)); // 3-4-5 right triangle
    });

    test('PoseLandmark and PoseFrame JSON serialization roundtrip', () {
      const landmark = PoseLandmark(
        type: PoseLandmarkType.leftKnee,
        x: 0.45,
        y: 0.72,
        confidence: 0.98,
      );
      final json = landmark.toJson();
      final decoded = PoseLandmark.fromJson(json);

      expect(decoded.type, equals(PoseLandmarkType.leftKnee));
      expect(decoded.x, equals(0.45));
      expect(decoded.y, equals(0.72));
      expect(decoded.confidence, equals(0.98));
    });
  });

  group('6. FormScore & ExerciseFormReport Models Tests', () {
    test('FormScore calculates grades and JSON roundtrip correctly', () {
      const score = FormScore(
        overallScore: 88.0,
        techniqueScore: 92.0,
        stabilityScore: 85.0,
        rangeOfMotionScore: 86.0,
        safetyScore: 90.0,
      );

      expect(score.grade, equals('A'));
      expect(score.status, equals('Optimal'));

      final json = score.toJson();
      final decoded = FormScore.fromJson(json);
      expect(decoded.overallScore, equals(88.0));
      expect(decoded.grade, equals('A'));
    });

    test('ExerciseFormReport serializes and deserializes accurately', () {
      final report = ExerciseFormReport(
        id: 'rep_001',
        userId: 'usr_athlete_01',
        exerciseName: 'Squat',
        videoPath: 'videos/squat_01.mp4',
        videoDurationSeconds: 4.5,
        score: const FormScore(
          overallScore: 82.0,
          techniqueScore: 80.0,
          stabilityScore: 85.0,
          rangeOfMotionScore: 90.0,
          safetyScore: 80.0,
        ),
        detectedIssues: const [
          FormIssue(
            problem: 'Knee valgus',
            severity: 'medium',
            solution: 'Push knees outward',
          ),
        ],
        positiveFeedback: const ['Good torso control'],
        recommendations: const ['Reduce weight by 10%'],
        coachSummary: 'Solid depth with minor knee cave on ascent.',
        createdAt: DateTime(2026, 8, 26),
      );

      final json = report.toJson();
      final decoded = ExerciseFormReport.fromJson(json);

      expect(decoded.id, equals('rep_001'));
      expect(decoded.exerciseName, equals('Squat'));
      expect(decoded.detectedIssues.length, equals(1));
      expect(decoded.detectedIssues.first.problem, equals('Knee valgus'));
      expect(decoded.positiveFeedback.first, equals('Good torso control'));
    });
  });
}
