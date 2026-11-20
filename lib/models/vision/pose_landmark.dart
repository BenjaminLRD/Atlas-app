/// Standard 33 body landmarks matching MediaPipe & ML Kit pose topology.
enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// A 3D spatial coordinate with visibility score for a single anatomical joint.
class PoseLandmark {
  final PoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double visibility; // 0.0 to 1.0 confidence/visibility score

  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    this.z = 0.0,
    this.visibility = 1.0,
  });

  factory PoseLandmark.fromJson(Map<String, dynamic> json) {
    return PoseLandmark(
      type: PoseLandmarkType.values.firstWhere(
        (e) => e.name == json['type'] || e.toString() == json['type'],
        orElse: () => PoseLandmarkType.nose,
      ),
      x: (json['x'] as num? ?? 0.0).toDouble(),
      y: (json['y'] as num? ?? 0.0).toDouble(),
      z: (json['z'] as num? ?? 0.0).toDouble(),
      visibility: (json['visibility'] as num? ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'x': x,
    'y': y,
    'z': z,
    'visibility': visibility,
  };

  PoseLandmark copyWith({
    PoseLandmarkType? type,
    double? x,
    double? y,
    double? z,
    double? visibility,
  }) {
    return PoseLandmark(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      visibility: visibility ?? this.visibility,
    );
  }
}
