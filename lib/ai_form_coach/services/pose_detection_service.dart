import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml_kit;
import '../models/pose_landmark.dart';

/// Service for detecting and tracking 33 anatomical landmarks using Google ML Kit Pose Detection.
/// Supports processing static images, video frames, and video files with confidence scoring.
class PoseDetectionService {
  static PoseDetectionService? _instance;
  static PoseDetectionService get instance =>
      _instance ??= PoseDetectionService();

  ml_kit.PoseDetector? _detector;

  /// Initializes or retrieves the Google ML Kit PoseDetector.
  ml_kit.PoseDetector get detector {
    return _detector ??= ml_kit.PoseDetector(
      options: ml_kit.PoseDetectorOptions(
        mode: ml_kit.PoseDetectionMode.single,
        model: ml_kit.PoseDetectionModel.accurate,
      ),
    );
  }

  /// Closes the active detector to release ML Kit native resources.
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }

  /// Processes an InputImage with ML Kit and converts the detected pose into PoseLandmarks.
  /// Returns a list of 33 body landmarks, or an empty list if no pose was detected.
  Future<List<PoseLandmark>> processInputImage(ml_kit.InputImage image) async {
    try {
      final List<ml_kit.Pose> poses = await detector.processImage(image);
      if (poses.isEmpty) return [];

      final primaryPose = selectPrimaryPose(poses);
      return extractLandmarksFromPose(primaryPose);
    } catch (e) {
      debugPrint('PoseDetectionService processInputImage notice: $e');
      return [];
    }
  }

  /// Selects the primary athlete when multiple poses are detected in a frame.
  /// Ranks poses by total keypoint visibility likelihood across major joints.
  ml_kit.Pose selectPrimaryPose(List<ml_kit.Pose> poses) {
    if (poses.length == 1) return poses.first;

    ml_kit.Pose bestPose = poses.first;
    double bestScore = -1.0;

    for (final pose in poses) {
      double totalLikelihood = 0.0;
      int count = 0;
      for (final lm in pose.landmarks.values) {
        totalLikelihood += lm.likelihood;
        count++;
      }
      final double score = count > 0 ? (totalLikelihood / count) * count : 0.0;
      if (score > bestScore) {
        bestScore = score;
        bestPose = pose;
      }
    }
    return bestPose;
  }

  /// Processes an image or video frame from a local file path.
  Future<List<PoseLandmark>> processImageFile(String filePath) async {
    try {
      final inputImage = ml_kit.InputImage.fromFilePath(filePath);
      return await processInputImage(inputImage);
    } catch (e) {
      debugPrint('PoseDetectionService processImageFile notice: $e');
      return [];
    }
  }

  /// Extracts and maps all 33 body landmarks from an ML Kit Pose instance.
  List<PoseLandmark> extractLandmarksFromPose(ml_kit.Pose pose) {
    final List<PoseLandmark> result = [];

    pose.landmarks.forEach((type, landmark) {
      result.add(
        PoseLandmark.fromMlKit(landmark, imageWidth: 1.0, imageHeight: 1.0),
      );
    });

    return result;
  }

  /// Calculates average detection confidence across primary anatomical joints.
  double calculateAverageConfidence(List<PoseLandmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;

    const primaryJoints = [
      PoseLandmarkNames.nose,
      PoseLandmarkNames.leftShoulder,
      PoseLandmarkNames.rightShoulder,
      PoseLandmarkNames.leftElbow,
      PoseLandmarkNames.rightElbow,
      PoseLandmarkNames.leftWrist,
      PoseLandmarkNames.rightWrist,
      PoseLandmarkNames.leftHip,
      PoseLandmarkNames.rightHip,
      PoseLandmarkNames.leftKnee,
      PoseLandmarkNames.rightKnee,
      PoseLandmarkNames.leftAnkle,
      PoseLandmarkNames.rightAnkle,
    ];

    double sum = 0.0;
    int count = 0;

    for (final name in primaryJoints) {
      final lm = findLandmark(landmarks, name);
      if (lm != null) {
        sum += lm.confidence;
        count++;
      }
    }

    if (count == 0) return 0.0;
    return (sum / count).clamp(0.0, 1.0);
  }

  /// Map lookup for fast landmark retrieval from a landmark collection.
  PoseLandmark? findLandmark(List<PoseLandmark> landmarks, String name) {
    final search = name.toLowerCase().replaceAll('_', '');
    for (final lm in landmarks) {
      final lmName = lm.name.toLowerCase().replaceAll('_', '');
      if (lmName == search) {
        return lm;
      }
    }
    return null;
  }

  /// Calculates the joint angle formed at vertex joint [bName] between [aName] and [cName].
  double? calculateJointAngle(
    List<PoseLandmark> landmarks,
    String aName,
    String bName,
    String cName, {
    double minConfidence = 0.5,
  }) {
    final a = findLandmark(landmarks, aName);
    final b = findLandmark(landmarks, bName);
    final c = findLandmark(landmarks, cName);
    return PoseLandmark.calculateAngle(a, b, c, minConfidence: minConfidence);
  }

  /// Creates a synthetic landmark collection simulating human body posture.
  /// Used for UI preview, offline analysis, and test suites.
  List<PoseLandmark> generateSimulatedLandmarks({
    required String exercise,
    required double phaseProgress, // 0.0 (start) to 1.0 (inflection/bottom)
  }) {
    final norm = exercise.toLowerCase();

    // Default neutral standing skeleton
    double leftShoulderY = 0.28;
    double leftElbowY = 0.42;
    double leftWristY = 0.55;
    double leftElbowX = 0.45;
    double leftWristX = 0.45;

    double leftHipY = 0.52;
    double leftKneeY = 0.72;
    double leftKneeX = 0.48;
    double leftAnkleY = 0.92;

    if (norm.contains('squat')) {
      // Squat: Hips drop into parallel depth, knees flex forward, chest stays proud
      final drop = phaseProgress * 0.20;
      leftHipY = 0.52 + drop;
      leftKneeX = 0.48 - (phaseProgress * 0.13);
      leftKneeY = 0.72;
    } else if (norm.contains('bench')) {
      // Bench press: Arms lower toward chest horizontally
      leftElbowY = 0.28 + (phaseProgress * 0.12);
      leftElbowX = 0.45 - (phaseProgress * 0.10);
      leftWristY = 0.28;
      leftWristX = 0.42;
    } else if (norm.contains('curl')) {
      // Bicep curl: Wrists elevate toward shoulders
      leftWristY = 0.55 - (phaseProgress * 0.24);
      leftWristX = 0.45 - (phaseProgress * 0.05);
    } else if (norm.contains('pushup') || norm.contains('push-up')) {
      // Pushup: Chest lowers to ground
      leftShoulderY = 0.55 + (phaseProgress * 0.12);
      leftHipY = 0.55 + (phaseProgress * 0.10);
      leftElbowY = 0.48 + (phaseProgress * 0.08);
    } else if (norm.contains('deadlift')) {
      // Deadlift: Hip hinge back, torso tilts forward
      leftHipY = 0.52 + (phaseProgress * 0.08);
      leftShoulderY = 0.28 + (phaseProgress * 0.16);
      leftWristY = 0.55 + (phaseProgress * 0.20);
    }

    return [
      PoseLandmark(
        name: PoseLandmarkNames.nose,
        x: 0.50,
        y: 0.18,
        z: 0.0,
        confidence: 0.99,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftShoulder,
        x: 0.42,
        y: leftShoulderY,
        z: 0.0,
        confidence: 0.98,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightShoulder,
        x: 0.58,
        y: leftShoulderY,
        z: 0.0,
        confidence: 0.98,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftElbow,
        x: leftElbowX,
        y: leftElbowY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightElbow,
        x: 1.0 - leftElbowX,
        y: leftElbowY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftWrist,
        x: leftWristX,
        y: leftWristY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightWrist,
        x: 1.0 - leftWristX,
        y: leftWristY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftHip,
        x: 0.45,
        y: leftHipY,
        z: 0.0,
        confidence: 0.96,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightHip,
        x: 0.55,
        y: leftHipY,
        z: 0.0,
        confidence: 0.96,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftKnee,
        x: leftKneeX,
        y: leftKneeY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightKnee,
        x: 1.0 - leftKneeX,
        y: leftKneeY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.leftAnkle,
        x: 0.48,
        y: leftAnkleY,
        z: 0.0,
        confidence: 0.95,
      ),
      PoseLandmark(
        name: PoseLandmarkNames.rightAnkle,
        x: 0.52,
        y: leftAnkleY,
        z: 0.0,
        confidence: 0.95,
      ),
    ];
  }
}
