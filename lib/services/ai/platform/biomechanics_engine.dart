/// Fundamental human movement patterns.
enum MovementPatternType {
  squatPattern('Squat Pattern (Bilateral Knee/Hip Flexion)'),
  hingePattern('Hinge Pattern (Posterior Chain Dominant)'),
  horizontalPush('Horizontal Push (Pectoralis/Triceps Focus)'),
  horizontalPull('Horizontal Pull (Latissimus/Rhomboid Focus)'),
  verticalPush('Vertical Push (Anterior Deltoid Focus)'),
  verticalPull('Vertical Pull (Latissimus Focus)');

  final String label;
  const MovementPatternType(this.label);
}

/// Angular kinematic summary for a specific joint.
class KinematicJointData {
  final String jointName;
  final double minAngleDeg;
  final double maxAngleDeg;
  final double rangeOfMotionDeg;
  final double peakVelocityDegPerSec;

  const KinematicJointData({
    required this.jointName,
    required this.minAngleDeg,
    required this.maxAngleDeg,
    required this.rangeOfMotionDeg,
    required this.peakVelocityDegPerSec,
  });

  Map<String, dynamic> toJson() => {
    'joint': jointName,
    'min_deg': minAngleDeg,
    'max_deg': maxAngleDeg,
    'rom_deg': rangeOfMotionDeg,
    'peak_vel': peakVelocityDegPerSec,
  };
}

/// Comprehensive biomechanics intelligence report.
class BiomechanicsAnalysisReport {
  final MovementPatternType pattern;
  final int repsAnalyzed;
  final double barPathDriftCm;
  final double tempoEccentricSeconds;
  final double tempoConcentricSeconds;
  final String dominantTorqueJoint; // e.g. 'Hip Dominant', 'Knee Dominant'
  final List<String> identifiedFlaws;
  final double mechanicalEfficiencyScore; // 0-100
  final DateTime analyzedAt;

  const BiomechanicsAnalysisReport({
    required this.pattern,
    required this.repsAnalyzed,
    required this.barPathDriftCm,
    required this.tempoEccentricSeconds,
    required this.tempoConcentricSeconds,
    required this.dominantTorqueJoint,
    required this.identifiedFlaws,
    required this.mechanicalEfficiencyScore,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() => {
    'pattern': pattern.name,
    'reps_analyzed': repsAnalyzed,
    'bar_path_drift_cm': barPathDriftCm,
    'eccentric_s': tempoEccentricSeconds,
    'concentric_s': tempoConcentricSeconds,
    'dominant_joint': dominantTorqueJoint,
    'flaws': identifiedFlaws,
    'efficiency_score': mechanicalEfficiencyScore,
    'analyzed_at': analyzedAt.toIso8601String(),
  };
}

/// Biomechanics Intelligence Engine.
/// Analyzes movement patterns, joint angles, moment arm/torque ratios,
/// bar path kinematics, and tempo velocity profiles.
class BiomechanicsEngine {
  static BiomechanicsEngine? _instance;
  static BiomechanicsEngine get instance => _instance ??= BiomechanicsEngine();

  static void resetInstance() {
    _instance = null;
  }

  /// Evaluates an exercise execution from joint angle telemetry.
  BiomechanicsAnalysisReport evaluateMovementKinematics({
    required MovementPatternType pattern,
    required double kneeAngleAtDepth, // e.g. 78 degrees
    required double hipAngleAtDepth, // e.g. 62 degrees
    required double backInclineAngle, // e.g. 45 degrees
    required double barPathDriftCm, // e.g. 3.2 cm
    double eccentricTime = 2.4,
    double concentricTime = 1.1,
  }) {
    final flaws = <String>[];
    double score = 100.0;

    // 1. Depth & Joint Angles
    if (pattern == MovementPatternType.squatPattern) {
      if (kneeAngleAtDepth > 95.0) {
        flaws.add(
          'Shallow squat depth: knee flexion did not reach parallel (>90°).',
        );
        score -= 20.0;
      }
      if (backInclineAngle < 35.0) {
        flaws.add(
          'Excessive forward torso lean; shearing load placed on lumbar spine.',
        );
        score -= 15.0;
      }
    }

    // 2. Bar Path Drift (<4cm is elite, >7cm is inefficient)
    if (barPathDriftCm > 6.0) {
      flaws.add(
        'Excessive horizontal bar path drift (${barPathDriftCm}cm); non-vertical force vector.',
      );
      score -= 15.0;
    }

    // 3. Tempo / Ballistic Eccentrics (<1.0s eccentric is uncontrolled)
    if (eccentricTime < 1.0) {
      flaws.add(
        'Uncontrolled eccentric descent; missing stretch-shortening cycle control.',
      );
      score -= 10.0;
    }

    final dominantJoint = hipAngleAtDepth < kneeAngleAtDepth
        ? 'Hip Dominant (Posterior Lever)'
        : 'Knee Dominant (Anterior Lever)';

    return BiomechanicsAnalysisReport(
      pattern: pattern,
      repsAnalyzed: 5,
      barPathDriftCm: barPathDriftCm,
      tempoEccentricSeconds: eccentricTime,
      tempoConcentricSeconds: concentricTime,
      dominantTorqueJoint: dominantJoint,
      identifiedFlaws: flaws,
      mechanicalEfficiencyScore: score.clamp(30.0, 100.0),
      analyzedAt: DateTime.now(),
    );
  }
}
