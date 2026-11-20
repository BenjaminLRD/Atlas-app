import 'dart:math' as math;
import 'pose_landmark.dart';

/// Single temporal video frame containing detected 3D anatomical pose landmarks.
class PoseFrame {
  final DateTime timestamp;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final double confidence; // Global frame confidence score

  const PoseFrame({
    required this.timestamp,
    required this.landmarks,
    this.confidence = 1.0,
  });

  /// Retrieve specific landmark or null if not detected
  PoseLandmark? getLandmark(PoseLandmarkType type) => landmarks[type];

  /// Check if essential keypoints have minimum visibility
  bool hasRequiredLandmarks(
    List<PoseLandmarkType> types, {
    double minVisibility = 0.5,
  }) {
    for (final type in types) {
      final lm = landmarks[type];
      if (lm == null || lm.visibility < minVisibility) {
        return false;
      }
    }
    return true;
  }

  /// Calculates the 2D planar joint angle (in degrees) formed at vertex joint [b]
  /// between line segments (a -> b) and (c -> b).
  ///
  /// Returns angle between 0.0° and 180.0°.
  /// Returns null if any of the three joints are missing or below [minVisibility].
  double? calculateAngle(
    PoseLandmarkType aType,
    PoseLandmarkType bType,
    PoseLandmarkType cType, {
    double minVisibility = 0.5,
  }) {
    final a = landmarks[aType];
    final b = landmarks[bType];
    final c = landmarks[cType];

    if (a == null || b == null || c == null) return null;
    if (a.visibility < minVisibility ||
        b.visibility < minVisibility ||
        c.visibility < minVisibility) {
      return null;
    }

    // Vector u = A - B
    final ux = a.x - b.x;
    final uy = a.y - b.y;

    // Vector v = C - B
    final vx = c.x - b.x;
    final vy = c.y - b.y;

    final dotProduct = (ux * vx) + (uy * vy);
    final magU = math.sqrt((ux * ux) + (uy * uy));
    final magV = math.sqrt((vx * vx) + (vy * vy));

    if (magU == 0.0 || magV == 0.0) return null;

    final cosTheta = (dotProduct / (magU * magV)).clamp(-1.0, 1.0);
    final radians = math.acos(cosTheta);
    return (radians * 180.0) / math.pi;
  }

  factory PoseFrame.fromLandmarkList(
    List<PoseLandmark> landmarkList, {
    DateTime? timestamp,
    double confidence = 1.0,
  }) {
    final map = <PoseLandmarkType, PoseLandmark>{};
    for (final lm in landmarkList) {
      map[lm.type] = lm;
    }
    return PoseFrame(
      timestamp: timestamp ?? DateTime.now(),
      landmarks: map,
      confidence: confidence,
    );
  }

  factory PoseFrame.fromJson(Map<String, dynamic> json) {
    final rawLandmarks = json['landmarks'] as List<dynamic>? ?? [];
    final map = <PoseLandmarkType, PoseLandmark>{};
    for (final item in rawLandmarks) {
      if (item is Map<String, dynamic>) {
        final lm = PoseLandmark.fromJson(item);
        map[lm.type] = lm;
      }
    }

    return PoseFrame(
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      landmarks: map,
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'confidence': confidence,
    'landmarks': landmarks.values.map((e) => e.toJson()).toList(),
  };
}
