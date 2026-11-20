import 'dart:math' as math;
import '../form_detection/pose_models.dart';

/// Recognized exercise types in real-time vision coaching.
enum VisionExerciseType {
  squat('Barbell / Bodyweight Squat'),
  deadlift('Deadlift / RDL'),
  benchPress('Bench Press / Pushup'),
  overheadPress('Overhead Press'),
  pullup('Pullup / Chin-up'),
  bicepCurl('Bicep Curl'),
  lunge('Lunge / Split Squat'),
  plank('Plank'),
  unknown('Exercise Identifying...');

  final String label;
  const VisionExerciseType(this.label);
}

/// Movement errors detected by real-time pose kinematics.
enum FormFaultType {
  kneeValgus('Knee Valgus (Knees Caving Inward)'),
  spinalRounding('Lumbar Spinal Flexion (Back Rounding)'),
  shallowDepth('Incomplete Range of Motion / Shallow Depth'),
  elbowFlare('Excessive Elbow Flaring (>75 degrees)'),
  barbellTilt('Barbell / Asymmetric Lateral Tilt'),
  excessiveForwardLean('Excessive Forward Trunk Incline'),
  none('Clean Form');

  final String description;
  const FormFaultType(this.description);
}

/// Evaluation result for a single camera frame or rep repetition.
class VisionFormEvaluation {
  final VisionExerciseType exercise;
  final double confidence; // 0.0 to 1.0
  final double kneeAngleDegrees;
  final double hipAngleDegrees;
  final double elbowAngleDegrees;
  final double backInclineDegrees;
  final int repCount;
  final bool isRepComplete;
  final double tempoEccentricSeconds;
  final double tempoConcentricSeconds;
  final List<FormFaultType> detectedFaults;
  final String liveCue;
  final double overallFormScore; // 0.0 to 100.0
  final DateTime timestamp;

  const VisionFormEvaluation({
    required this.exercise,
    required this.confidence,
    required this.kneeAngleDegrees,
    required this.hipAngleDegrees,
    required this.elbowAngleDegrees,
    required this.backInclineDegrees,
    required this.repCount,
    required this.isRepComplete,
    required this.tempoEccentricSeconds,
    required this.tempoConcentricSeconds,
    required this.detectedFaults,
    required this.liveCue,
    required this.overallFormScore,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'exercise': exercise.name,
    'confidence': confidence,
    'knee_angle': kneeAngleDegrees,
    'hip_angle': hipAngleDegrees,
    'elbow_angle': elbowAngleDegrees,
    'back_incline': backInclineDegrees,
    'rep_count': repCount,
    'is_rep_complete': isRepComplete,
    'eccentric_sec': tempoEccentricSeconds,
    'concentric_sec': tempoConcentricSeconds,
    'faults': detectedFaults.map((f) => f.name).toList(),
    'live_cue': liveCue,
    'form_score': overallFormScore,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Real-Time Vision Coaching Engine.
/// Computes joint kinematics, detects biomechanical form faults,
/// tracks rep count and tempo, and generates instant audio-visual cues.
class VisionCoachService {
  static VisionCoachService? _instance;
  static VisionCoachService get instance => _instance ??= VisionCoachService();

  static void resetInstance() {
    _instance = null;
  }

  int _currentRepCount = 0;
  bool _isInRep = false;
  bool _isBottomReached = false;
  DateTime? _repStartTime;
  DateTime? _bottomInflectionTime;
  double _lastEccentricDuration = 0.0;
  double _lastConcentricDuration = 0.0;

  int get currentRepCount => _currentRepCount;

  void resetReps() {
    _currentRepCount = 0;
    _isInRep = false;
    _isBottomReached = false;
    _repStartTime = null;
    _bottomInflectionTime = null;
    _lastEccentricDuration = 0.0;
    _lastConcentricDuration = 0.0;
  }

  /// Evaluates a real-time PoseFrame and returns kinematics, faults, and live cues.
  VisionFormEvaluation evaluateFrame(
    PoseFrame frame, {
    VisionExerciseType exerciseHint = VisionExerciseType.squat,
  }) {
    final now = DateTime.now();

    // 1. Extract Landmark Keypoints
    final leftHip = frame.get(PoseLandmarkType.leftHip);
    final rightHip = frame.get(PoseLandmarkType.rightHip);
    final leftKnee = frame.get(PoseLandmarkType.leftKnee);
    final rightKnee = frame.get(PoseLandmarkType.rightKnee);
    final leftAnkle = frame.get(PoseLandmarkType.leftAnkle);
    final rightAnkle = frame.get(PoseLandmarkType.rightAnkle);
    final leftShoulder = frame.get(PoseLandmarkType.leftShoulder);
    final leftElbow = frame.get(PoseLandmarkType.leftElbow);
    final leftWrist = frame.get(PoseLandmarkType.leftWrist);

    // 2. Compute Joint Angles
    double kneeAngle = 180.0;
    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    } else if (rightHip != null && rightKnee != null && rightAnkle != null) {
      kneeAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
    }

    double hipAngle = 180.0;
    if (leftShoulder != null && leftHip != null && leftKnee != null) {
      hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);
    }

    double elbowAngle = 180.0;
    if (leftShoulder != null && leftElbow != null && leftWrist != null) {
      elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    }

    double backIncline = 90.0;
    if (leftShoulder != null && leftHip != null) {
      final dx = (leftShoulder.x - leftHip.x).abs();
      final dy = (leftShoulder.y - leftHip.y).abs();
      backIncline = (math.atan2(dy, dx) * 180.0 / math.pi);
    }

    // 3. Biomechanical Fault Detection
    final faults = <FormFaultType>[];
    String liveCue = 'Form is solid. Maintain smooth tempo.';
    double formScore = 95.0;

    // Check Knee Valgus (Squat / Lunge)
    if (leftKnee != null && rightKnee != null && leftAnkle != null && rightAnkle != null) {
      final kneeDistance = (leftKnee.x - rightKnee.x).abs();
      final ankleDistance = (leftAnkle.x - rightAnkle.x).abs();
      if (kneeDistance < (ankleDistance * 0.75) && kneeAngle < 165) {
        faults.add(FormFaultType.kneeValgus);
        liveCue = 'Push knees out! Avoid knee caving.';
        formScore -= 20.0;
      }
    }

    // Check Spinal Rounding / Excessive Lean
    if (backIncline < 40.0 && exerciseHint == VisionExerciseType.squat) {
      faults.add(FormFaultType.excessiveForwardLean);
      liveCue = 'Keep chest proud - avoid excessive forward lean.';
      formScore -= 15.0;
    }

    // Check Shallow Depth on Squats
    if (_isInRep && _isBottomReached && kneeAngle > 110.0 && exerciseHint == VisionExerciseType.squat) {
      faults.add(FormFaultType.shallowDepth);
      liveCue = 'Sink deeper - aim for thighs parallel to floor.';
      formScore -= 10.0;
    }

    // 4. Rep State Machine & Tempo Tracking
    bool repCompletedThisFrame = false;

    if (exerciseHint == VisionExerciseType.squat) {
      // Start eccentric descent (knee angle breaks < 155°)
      if (!_isInRep && kneeAngle < 155.0) {
        _isInRep = true;
        _isBottomReached = false;
        _repStartTime = now;
      }

      // Reached bottom inflection (knee angle < 95°)
      if (_isInRep && kneeAngle <= 95.0 && !_isBottomReached) {
        _isBottomReached = true;
        _bottomInflectionTime = now;
        if (_repStartTime != null) {
          _lastEccentricDuration =
              now.difference(_repStartTime!).inMilliseconds / 1000.0;
        }
      }

      // Completed concentric ascent / lockout (knee angle returns > 165°)
      if (_isInRep && _isBottomReached && kneeAngle > 165.0) {
        _currentRepCount++;
        repCompletedThisFrame = true;
        _isInRep = false;
        _isBottomReached = false;
        if (_bottomInflectionTime != null) {
          _lastConcentricDuration =
              now.difference(_bottomInflectionTime!).inMilliseconds / 1000.0;
        }
        liveCue = 'Rep $_currentRepCount locked! Solid control.';
      }
    }

    if (faults.isEmpty) {
      faults.add(FormFaultType.none);
    }

    return VisionFormEvaluation(
      exercise: exerciseHint,
      confidence: 0.94,
      kneeAngleDegrees: double.parse(kneeAngle.toStringAsFixed(1)),
      hipAngleDegrees: double.parse(hipAngle.toStringAsFixed(1)),
      elbowAngleDegrees: double.parse(elbowAngle.toStringAsFixed(1)),
      backInclineDegrees: double.parse(backIncline.toStringAsFixed(1)),
      repCount: _currentRepCount,
      isRepComplete: repCompletedThisFrame,
      tempoEccentricSeconds: double.parse(_lastEccentricDuration.toStringAsFixed(1)),
      tempoConcentricSeconds: double.parse(_lastConcentricDuration.toStringAsFixed(1)),
      detectedFaults: faults,
      liveCue: liveCue,
      overallFormScore: formScore.clamp(0.0, 100.0),
      timestamp: now,
    );
  }

  /// Calculates the 2D interior angle at vertex point B formed by points A-B-C in degrees.
  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }
}
