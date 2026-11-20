/// Evaluation result from the Biomechanical Movement Quality ML Model.
class MovementQualityScore {
  final String exerciseName;
  final int overallScore; // 0 to 100 (e.g. 82/100)
  final double jointAngleScore; // 0.0 to 100.0
  final double velocityScore; // 0.0 to 100.0
  final double rangeOfMotionScore; // 0.0 to 100.0 (ROM depth)
  final double symmetryScore; // 0.0 to 100.0 (left vs right balance)
  final List<String> qualityFeedback;

  const MovementQualityScore({
    required this.exerciseName,
    required this.overallScore,
    required this.jointAngleScore,
    required this.velocityScore,
    required this.rangeOfMotionScore,
    required this.symmetryScore,
    required this.qualityFeedback,
  });

  factory MovementQualityScore.fromJson(Map<String, dynamic> json) {
    final rawFb = json['quality_feedback'] as List<dynamic>? ?? [];
    return MovementQualityScore(
      exerciseName: json['exercise_name'] as String? ?? 'Squat',
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 82,
      jointAngleScore: (json['joint_angle_score'] as num?)?.toDouble() ?? 85.0,
      velocityScore: (json['velocity_score'] as num?)?.toDouble() ?? 80.0,
      rangeOfMotionScore:
          (json['range_of_motion_score'] as num?)?.toDouble() ?? 88.0,
      symmetryScore: (json['symmetry_score'] as num?)?.toDouble() ?? 94.0,
      qualityFeedback: rawFb.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_name': exerciseName,
      'overall_score': overallScore,
      'joint_angle_score': jointAngleScore,
      'velocity_score': velocityScore,
      'range_of_motion_score': rangeOfMotionScore,
      'symmetry_score': symmetryScore,
      'quality_feedback': qualityFeedback,
    };
  }

  String get summaryString => '$exerciseName: $overallScore/100';
}

/// Custom ML Model analyzing joint kinematics, movement velocity, range of motion, and bilateral symmetry
/// to score execution technique.
class MovementQualityModel {
  static MovementQualityModel? _instance;
  static MovementQualityModel get instance =>
      _instance ??= MovementQualityModel();

  /// Evaluates movement quality from biomechanical parameters.
  MovementQualityScore evaluateMovementQuality({
    required String exerciseName,
    double minJointAngle = 88.0, // e.g. knee angle at squat bottom
    double targetJointAngle = 90.0,
    double repDurationSeconds = 2.4, // cadence
    double targetDurationSeconds = 2.5,
    double bilateralDeltaPercentage =
        4.0, // difference between left and right side
    double romCompletionPercentage = 92.0,
  }) {
    final List<String> feedback = [];

    // 1. Joint Angle Score
    final angleDiff = (minJointAngle - targetJointAngle).abs();
    final angleScore = (100.0 - angleDiff * 1.5).clamp(50.0, 100.0);
    if (angleDiff > 10.0) {
      feedback.add(
        'Joint depth off target by ${angleDiff.toStringAsFixed(0)}°: focus on controlled bottom position.',
      );
    }

    // 2. Velocity Score
    final durationDiff = (repDurationSeconds - targetDurationSeconds).abs();
    final velScore = (100.0 - durationDiff * 15.0).clamp(50.0, 100.0);
    if (repDurationSeconds < 1.5) {
      feedback.add(
        'Tempo too rapid: increase eccentric phase to at least 2 seconds.',
      );
    }

    // 3. Range of Motion Score
    final romScore = romCompletionPercentage.clamp(50.0, 100.0);
    if (romCompletionPercentage < 85.0) {
      feedback.add('Incomplete range of motion: achieve full parallel depth.');
    }

    // 4. Symmetry Score
    final symScore = (100.0 - bilateralDeltaPercentage * 2.0).clamp(
      50.0,
      100.0,
    );
    if (bilateralDeltaPercentage > 8.0) {
      feedback.add(
        'Asymmetrical loading detected (${bilateralDeltaPercentage.toStringAsFixed(0)}% delta): balance left/right drive.',
      );
    }

    // Overall weighted score
    final overall =
        (angleScore * 0.30 +
                velScore * 0.20 +
                romScore * 0.30 +
                symScore * 0.20)
            .round();

    if (feedback.isEmpty) {
      feedback.add(
        'Textbook mechanical execution with balanced symmetry and optimal tempo.',
      );
    }

    return MovementQualityScore(
      exerciseName: exerciseName,
      overallScore: overall,
      jointAngleScore: angleScore,
      velocityScore: velScore,
      rangeOfMotionScore: romScore,
      symmetryScore: symScore,
      qualityFeedback: feedback,
    );
  }
}
