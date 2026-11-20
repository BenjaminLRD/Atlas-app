import 'dart:math' as math;

/// Single anatomical keypoint for computer vision pose tracking and form analysis.
class PoseLandmark {
  final String name;
  final double x;
  final double y;
  final double z;
  final double confidence;

  PoseLandmark({
    required this.name,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  /// Alias getter for visibility score to maintain compatibility across engines.
  double get visibility => confidence;

  /// Calculates the 2D planar joint angle (in degrees) formed at vertex joint [b]
  /// between line segments (a -> b) and (c -> b).
  ///
  /// Returns angle between 0.0° and 180.0°.
  /// Returns null if any joint confidence is below [minConfidence].
  static double? calculateAngle(
    PoseLandmark? a,
    PoseLandmark? b,
    PoseLandmark? c, {
    double minConfidence = 0.5,
  }) {
    if (a == null || b == null || c == null) return null;
    if (a.confidence < minConfidence ||
        b.confidence < minConfidence ||
        c.confidence < minConfidence) {
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
    return math.acos(cosTheta) * (180.0 / math.pi);
  }

  factory PoseLandmark.fromJson(Map<String, dynamic> json) {
    return PoseLandmark(
      name: json['name'] as String? ?? json['joint'] as String? ?? 'unknown',
      x: (json['x'] as num? ?? 0.0).toDouble(),
      y: (json['y'] as num? ?? 0.0).toDouble(),
      z: (json['z'] as num? ?? 0.0).toDouble(),
      confidence:
          (json['confidence'] as num? ?? json['visibility'] as num? ?? 1.0)
              .toDouble(),
    );
  }

  /// Creates a PoseLandmark from Google ML Kit PoseLandmark instance.
  factory PoseLandmark.fromMlKit(
    dynamic mlKitLandmark, {
    double imageWidth = 1.0,
    double imageHeight = 1.0,
  }) {
    final dynamic typeObj = mlKitLandmark.type;
    String typeStr;
    if (typeObj is Enum) {
      typeStr = typeObj.name;
    } else {
      typeStr = typeObj.toString().split('.').last;
    }
    final name = _convertMlKitTypeToName(typeStr);
    final rawX = (mlKitLandmark.x as num).toDouble();
    final rawY = (mlKitLandmark.y as num).toDouble();
    final rawZ = (mlKitLandmark.z as num).toDouble();
    final likelihood = (mlKitLandmark.likelihood as num).toDouble();

    final normX = imageWidth > 1.0 ? (rawX / imageWidth).clamp(0.0, 1.0) : rawX;
    final normY = imageHeight > 1.0
        ? (rawY / imageHeight).clamp(0.0, 1.0)
        : rawY;

    return PoseLandmark(
      name: name,
      x: normX,
      y: normY,
      z: rawZ,
      confidence: likelihood.clamp(0.0, 1.0),
    );
  }

  static String _convertMlKitTypeToName(String typeName) {
    final exp = RegExp(r'(?<=[a-z])[A-Z]');
    return typeName
        .replaceAllMapped(exp, (m) => '_${m.group(0)}')
        .toLowerCase();
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'z': z,
    'confidence': confidence,
  };

  PoseLandmark copyWith({
    String? name,
    double? x,
    double? y,
    double? z,
    double? confidence,
  }) {
    return PoseLandmark(
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Standard 33 MediaPipe / Google ML Kit landmark names.
class PoseLandmarkNames {
  static const String nose = 'nose';
  static const String leftEyeInner = 'left_eye_inner';
  static const String leftEye = 'left_eye';
  static const String leftEyeOuter = 'left_eye_outer';
  static const String rightEyeInner = 'right_eye_inner';
  static const String rightEye = 'right_eye';
  static const String rightEyeOuter = 'right_eye_outer';
  static const String leftEar = 'left_ear';
  static const String rightEar = 'right_ear';
  static const String mouthLeft = 'mouth_left';
  static const String mouthRight = 'mouth_right';
  static const String leftShoulder = 'left_shoulder';
  static const String rightShoulder = 'right_shoulder';
  static const String leftElbow = 'left_elbow';
  static const String rightElbow = 'right_elbow';
  static const String leftWrist = 'left_wrist';
  static const String rightWrist = 'right_wrist';
  static const String leftPinky = 'left_pinky';
  static const String rightPinky = 'right_pinky';
  static const String leftIndex = 'left_index';
  static const String rightIndex = 'right_index';
  static const String leftThumb = 'left_thumb';
  static const String rightThumb = 'right_thumb';
  static const String leftHip = 'left_hip';
  static const String rightHip = 'right_hip';
  static const String leftKnee = 'left_knee';
  static const String rightKnee = 'right_knee';
  static const String leftAnkle = 'left_ankle';
  static const String rightAnkle = 'right_ankle';
  static const String leftHeel = 'left_heel';
  static const String rightHeel = 'right_heel';
  static const String leftFootIndex = 'left_foot_index';
  static const String rightFootIndex = 'right_foot_index';
}
