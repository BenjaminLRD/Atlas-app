import 'dart:math' as math;

/// Standard MediaPipe / ML Kit compatible anatomical landmark keys.
enum PoseLandmarkType {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  neck,
  spine,
  midHip,
}

/// 3D coordinate point of an anatomical landmark.
class PoseLandmark {
  final PoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double confidence;

  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    this.z = 0.0,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'x': x,
    'y': y,
    'z': z,
    'confidence': confidence,
  };

  factory PoseLandmark.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'nose';
    final type = PoseLandmarkType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => PoseLandmarkType.nose,
    );
    return PoseLandmark(
      type: type,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// A snapshot of all anatomical landmarks detected in a single video frame.
class PoseFrame {
  final int frameIndex;
  final double timestampMs;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  const PoseFrame({
    required this.frameIndex,
    required this.timestampMs,
    required this.landmarks,
  });

  PoseLandmark? get(PoseLandmarkType type) => landmarks[type];

  bool hasAll(List<PoseLandmarkType> types) {
    return types.every((t) => landmarks.containsKey(t) && (landmarks[t]?.confidence ?? 0.0) > 0.4);
  }

  /// Calculates the joint angle at vertex [b] formed by rays [ba] and [bc] in degrees (0° - 180°).
  double? getAngle(PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
    final pA = landmarks[a];
    final pB = landmarks[b];
    final pC = landmarks[c];
    if (pA == null || pB == null || pC == null) return null;

    final v1x = pA.x - pB.x;
    final v1y = pA.y - pB.y;
    final v2x = pC.x - pB.x;
    final v2y = pC.y - pB.y;

    final dot = v1x * v2x + v1y * v2y;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);

    if (mag1 == 0 || mag2 == 0) return 0.0;
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * (180.0 / math.pi);
  }

  /// Calculates the angle of the segment [bottom]->[top] relative to the vertical line (0° = perfectly upright).
  double? getVerticalAngle(PoseLandmarkType top, PoseLandmarkType bottom) {
    final pTop = landmarks[top];
    final pBottom = landmarks[bottom];
    if (pTop == null || pBottom == null) return null;

    final dx = pTop.x - pBottom.x;
    final dy = (pTop.y - pBottom.y).abs();
    if (dy == 0) return 90.0;

    final angleRad = math.atan2(dx.abs(), dy);
    return angleRad * (180.0 / math.pi);
  }

  /// Calculates Euclidean distance between two landmarks.
  double? getDistance(PoseLandmarkType a, PoseLandmarkType b) {
    final pA = landmarks[a];
    final pB = landmarks[b];
    if (pA == null || pB == null) return null;
    final dx = pA.x - pB.x;
    final dy = pA.y - pB.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns midpoint coordinate between [a] and [b].
  PoseLandmark? getMidpoint(PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType outputType) {
    final pA = landmarks[a];
    final pB = landmarks[b];
    if (pA == null || pB == null) return null;
    return PoseLandmark(
      type: outputType,
      x: (pA.x + pB.x) / 2.0,
      y: (pA.y + pB.y) / 2.0,
      z: (pA.z + pB.z) / 2.0,
      confidence: math.min(pA.confidence, pB.confidence),
    );
  }

  Map<String, dynamic> toJson() => {
    'frameIndex': frameIndex,
    'timestampMs': timestampMs,
    'landmarks': landmarks.map((k, v) => MapEntry(k.name, v.toJson())),
  };

  factory PoseFrame.fromJson(Map<String, dynamic> json) {
    final frameIndex = (json['frameIndex'] as num?)?.toInt() ?? 0;
    final timestampMs = (json['timestampMs'] as num?)?.toDouble() ?? 0.0;
    final landmarksMap = <PoseLandmarkType, PoseLandmark>{};
    if (json['landmarks'] is Map) {
      (json['landmarks'] as Map).forEach((k, v) {
        final type = PoseLandmarkType.values.firstWhere(
          (e) => e.name == k.toString(),
          orElse: () => PoseLandmarkType.nose,
        );
        landmarksMap[type] = PoseLandmark.fromJson(Map<String, dynamic>.from(v as Map));
      });
    }
    return PoseFrame(
      frameIndex: frameIndex,
      timestampMs: timestampMs,
      landmarks: landmarksMap,
    );
  }
}

/// A sequential time-series of pose estimation frames extracted from an exercise video.
class PoseSequence {
  final String videoPath;
  final String exerciseName;
  final double durationSeconds;
  final double fps;
  final List<PoseFrame> frames;

  const PoseSequence({
    required this.videoPath,
    required this.exerciseName,
    required this.durationSeconds,
    this.fps = 30.0,
    required this.frames,
  });

  bool get isEmpty => frames.isEmpty;
  int get frameCount => frames.length;
}
