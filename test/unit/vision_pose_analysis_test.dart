import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/vision/pose_frame.dart';
import 'package:atlas/models/vision/pose_landmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('PoseFrame & Mathematical Joint Angle Kinematics', () {
    test('calculateAngle accurately computes exact 90-degree right angle', () {
      final frame = PoseFrame.fromLandmarkList([
        const PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.0, y: 1.0),
        const PoseLandmark(
          type: PoseLandmarkType.leftKnee,
          x: 0.0,
          y: 0.0,
        ), // Vertex
        const PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 1.0, y: 0.0),
      ]);

      final angle = frame.calculateAngle(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      );

      expect(angle, isNotNull);
      expect((angle! - 90.0).abs(), lessThan(0.01));
    });

    test(
      'calculateAngle accurately computes exact 180-degree straight angle',
      () {
        final frame = PoseFrame.fromLandmarkList([
          const PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.0, y: 1.0),
          const PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.0,
            y: 0.0,
          ), // Vertex
          const PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0.0, y: -1.0),
        ]);

        final angle = frame.calculateAngle(
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        );

        expect(angle, isNotNull);
        expect((angle! - 180.0).abs(), lessThan(0.01));
      },
    );

    test(
      'calculateAngle returns null when keypoints are missing or low visibility',
      () {
        final frame = PoseFrame.fromLandmarkList([
          const PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.0,
            y: 1.0,
            visibility: 0.2,
          ),
          const PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.0,
            y: 0.0,
            visibility: 0.9,
          ),
        ]);

        final angle = frame.calculateAngle(
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        );

        expect(angle, isNull);
      },
    );
  });
}
