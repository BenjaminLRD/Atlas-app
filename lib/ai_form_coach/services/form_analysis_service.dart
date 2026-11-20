import 'dart:math' as math;
import '../models/pose_landmark.dart';
import '../models/form_feedback.dart';
import '../models/exercise_analysis.dart';
import 'angle_smoother.dart';
import 'pose_detection_service.dart';

/// Exercises the form coach can analyse.
class SupportedMvpExercises {
  static const String squat = 'Squat';
  static const String benchPress = 'Bench Press';
  static const String bicepCurl = 'Bicep Curl';
  static const String pushUp = 'Push-up';
  static const String deadlift = 'Deadlift';
  static const String overheadPress = 'Overhead Press';

  static const List<String> list = [
    squat,
    benchPress,
    deadlift,
    overheadPress,
    pushUp,
    bicepCurl,
  ];

  static bool _isOverheadPress(String norm) =>
      norm.contains('overhead') ||
      norm.contains('shoulder press') ||
      norm.contains('military') ||
      norm.contains('ohp');

  static bool _isPushUp(String norm) =>
      norm.contains('pushup') ||
      norm.contains('push-up') ||
      norm.contains('push up');

  static bool isSupported(String exerciseName) {
    final norm = exerciseName.toLowerCase();
    return norm.contains('squat') ||
        norm.contains('bench') ||
        norm.contains('curl') ||
        _isPushUp(norm) ||
        norm.contains('deadlift') ||
        _isOverheadPress(norm);
  }

  static String normalize(String exerciseName) {
    final norm = exerciseName.toLowerCase();
    if (norm.contains('squat')) return squat;
    if (norm.contains('bench')) return benchPress;
    if (_isOverheadPress(norm)) return overheadPress;
    if (norm.contains('curl')) return bicepCurl;
    if (_isPushUp(norm)) return pushUp;
    if (norm.contains('deadlift')) return deadlift;
    return squat;
  }

  /// Where to put the phone so the checks for [exercise] can see the body.
  static String cameraTip(String exercise) {
    switch (normalize(exercise)) {
      case benchPress:
        return 'Place the phone at your head or feet end, level with the bench.';
      case pushUp:
        return 'Place the phone side-on, about 2 m away, at floor height.';
      case bicepCurl:
      case overheadPress:
        return 'Place the phone side-on at chest height, about 2–3 m away.';
      default:
        return 'Place the phone side-on, 2–3 m away, so your whole body is in view. Face it to check knee tracking.';
    }
  }
}

/// Movement phase state machine for real-time and post-set rep tracking.
enum MovementPhase { ready, eccentric, inflection, concentric }

/// How one exercise's primary joint angle moves through a rep.
class _RepPattern {
  /// True when a rep starts with the joint extended (squat), false when it
  /// starts flexed (deadlift from the floor, press from the rack position).
  final bool startsExtended;

  /// Angle at the start/end position.
  final double start;

  /// Angle the rep must reach at its turning point.
  final double turn;

  const _RepPattern(this.startsExtended, this.start, this.turn);
}

/// Biomechanical form checks from pose landmarks.
///
/// Works with normalised (0–1) or pixel coordinates: checks use joint angles
/// and distances relative to torso length. Each check uses whichever side of
/// the body the camera sees better. When the joints an exercise needs are not
/// visible, the frame is reported as not judgeable instead of guessed.
class FormAnalysisService {
  static FormAnalysisService? _instance;
  static FormAnalysisService get instance =>
      _instance ??= FormAnalysisService();

  final PoseDetectionService _poseService = PoseDetectionService.instance;

  static const double _minVisibility = 0.5;
  static const double _repHysteresis = 12.0;

  /// Live-camera smoothing of the angle the rep counter follows. Deliberately
  /// light (alpha 0.6, first 2 frames unsmoothed): it removes single-frame
  /// spikes without delaying a real rep by more than about a frame.
  static const double liveSmoothingAlpha = 0.6;
  static const int liveSmoothingWarmupFrames = 2;

  final AngleSmoother _primarySmoother = AngleSmoother(
    alpha: liveSmoothingAlpha,
    warmupFrames: liveSmoothingWarmupFrames,
  );

  // Rep tracking state
  MovementPhase _phase = MovementPhase.ready;
  int _completedReps = 0;
  String _activeExercise = SupportedMvpExercises.squat;
  double? _repExtreme;
  final List<double> _repTurnAngles = [];
  final List<double> _partialRepAngles = [];

  String get activeExercise => _activeExercise;
  int get completedReps => _completedReps;
  MovementPhase get currentPhase => _phase;

  /// The turning-point angle of each completed rep (deepest knee angle for
  /// a squat, highest hip angle for a deadlift...), for per-rep depth checks.
  List<double> get repTurnAngles => List.unmodifiable(_repTurnAngles);

  /// Reps that returned to the start without reaching full range: the angle
  /// they did reach. These are not counted in [completedReps].
  List<double> get partialRepAngles => List.unmodifiable(_partialRepAngles);

  void reset({String? exercise}) {
    _phase = MovementPhase.ready;
    _completedReps = 0;
    _repExtreme = null;
    _repTurnAngles.clear();
    _partialRepAngles.clear();
    _primarySmoother.reset();
    if (exercise != null) {
      _activeExercise = SupportedMvpExercises.normalize(exercise);
    }
  }

  /// Evaluates a single frame. With [judgeDepth] false, range-of-motion
  /// checks are skipped (live mode judges depth once per rep instead, via
  /// [depthFeedbackForRep]).
  FormFeedback analyzeFrame({
    required String exerciseName,
    required List<PoseLandmark> landmarks,
    bool judgeDepth = true,
  }) {
    switch (SupportedMvpExercises.normalize(exerciseName)) {
      case SupportedMvpExercises.benchPress:
        return _analyzeBenchPress(landmarks, judgeDepth);
      case SupportedMvpExercises.bicepCurl:
        return _analyzeBicepCurl(landmarks, judgeDepth);
      case SupportedMvpExercises.pushUp:
        return _analyzePushUp(landmarks, judgeDepth);
      case SupportedMvpExercises.deadlift:
        return _analyzeDeadlift(landmarks);
      case SupportedMvpExercises.overheadPress:
        return _analyzeOverheadPress(landmarks, judgeDepth);
      case SupportedMvpExercises.squat:
      default:
        return _analyzeSquat(landmarks, judgeDepth);
    }
  }

  /// Range-of-motion feedback for one completed rep, from its turning-point
  /// angle. Returns null when the rep reached full range.
  String? depthFeedbackForRep(String exerciseName, double turnAngle) {
    switch (SupportedMvpExercises.normalize(exerciseName)) {
      case SupportedMvpExercises.squat:
        return turnAngle > 100
            ? 'Squat deeper: aim for thighs at parallel.'
            : null;
      case SupportedMvpExercises.benchPress:
        return turnAngle > 95
            ? 'Lower the bar to touch your chest lightly.'
            : null;
      case SupportedMvpExercises.pushUp:
        return turnAngle > 95 ? 'Lower your chest closer to the floor.' : null;
      case SupportedMvpExercises.bicepCurl:
        return turnAngle > 65
            ? 'Curl all the way up to full contraction.'
            : null;
      case SupportedMvpExercises.overheadPress:
        return turnAngle < 160 ? 'Press to a full lockout overhead.' : null;
      case SupportedMvpExercises.deadlift:
        return turnAngle < 165
            ? 'Stand all the way up to finish each rep.'
            : null;
    }
    return null;
  }

  /// Evaluates a sequence of frames (an uploaded video) as one set.
  ExerciseAnalysis analyzeSet({
    required String exerciseName,
    required List<List<PoseLandmark>> frames,
    Duration? duration,
  }) {
    final norm = SupportedMvpExercises.normalize(exerciseName);
    reset(exercise: norm);

    final allWarnings = <String>{};
    final allCorrections = <String>{};
    final allPositives = <String>{};
    int scoreSum = 0;
    double confidenceSum = 0.0;
    int judged = 0;

    for (final frame in frames) {
      updateRepCounter(norm, frame);
      final feedback = analyzeFrame(
        exerciseName: norm,
        landmarks: frame,
        judgeDepth: false,
      );
      if (!feedback.bodyVisible) continue;
      judged++;
      scoreSum += feedback.score;
      confidenceSum += feedback.confidence;
      allWarnings.addAll(feedback.warnings);
      allCorrections.addAll(feedback.corrections);
      allPositives.addAll(feedback.positiveFeedback);
    }

    // Range of motion is judged per rep: reps that turned back before full
    // range are not counted and get a depth note.
    final shallowReps = _partialRepAngles.length;
    for (final angle in _partialRepAngles) {
      final note = depthFeedbackForRep(norm, angle);
      if (note != null) allCorrections.add(note);
    }
    if (shallowReps > 0) {
      allWarnings.add(
        '$shallowReps ${shallowReps == 1 ? 'rep' : 'reps'} short of full range (not counted)',
      );
    } else if (_completedReps > 0) {
      allPositives.add('Full range of motion on every rep');
    }
    if (norm == SupportedMvpExercises.squat && _repTurnAngles.isNotEmpty) {
      final deepest = _repTurnAngles.reduce(math.max);
      allPositives.add(
        deepest <= 95 ? 'Great depth' : 'Good depth at parallel',
      );
    }

    final avgScore = judged == 0
        ? 0
        : ((scoreSum / judged) - shallowReps * 15).round().clamp(0, 100);
    final avgConfidence = judged == 0 ? 0.0 : confidenceSum / judged;

    final finalFeedback = FormFeedback(
      score: avgScore,
      confidence: avgConfidence.clamp(0.0, 1.0),
      warnings: allWarnings.toList(),
      corrections: judged == 0
          ? [
              'Your body was not clearly visible. ${SupportedMvpExercises.cameraTip(norm)}',
            ]
          : allCorrections.toList(),
      positiveFeedback: allPositives.toList(),
      bodyVisible: judged > 0,
    );

    return ExerciseAnalysis(
      exerciseName: norm,
      feedback: finalFeedback,
      repCount: _completedReps,
      detectedMistakes: allWarnings.toList(),
      corrections: finalFeedback.corrections,
      jointAngles: const {},
      metrics: {
        'durationSeconds': duration?.inSeconds ?? (frames.length * 0.1).round(),
        'frameCount': frames.length,
        'judgedFrames': judged,
        'confidencePercentage': finalFeedback.confidencePercentage,
      },
    );
  }

  // ===========================================================================
  // Geometry helpers
  // ===========================================================================

  PoseLandmark? _visible(List<PoseLandmark> landmarks, String name) {
    final lm = _poseService.findLandmark(landmarks, name);
    return lm != null && lm.confidence >= _minVisibility ? lm : null;
  }

  /// 'left' or 'right': the side whose [joints] the camera sees better.
  String _bestSide(List<PoseLandmark> landmarks, List<String> joints) {
    double score(String side) {
      var total = 0.0;
      for (final j in joints) {
        total +=
            _poseService.findLandmark(landmarks, '${side}_$j')?.confidence ?? 0;
      }
      return total;
    }

    return score('right') > score('left') ? 'right' : 'left';
  }

  /// The [joints] on [side], or null if any is not visible.
  Map<String, PoseLandmark>? _joints(
    List<PoseLandmark> landmarks,
    String side,
    List<String> joints,
  ) {
    final result = <String, PoseLandmark>{};
    for (final j in joints) {
      final lm = _visible(landmarks, '${side}_$j');
      if (lm == null) return null;
      result[j] = lm;
    }
    return result;
  }

  static double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x, aby = a.y - b.y;
    final cbx = c.x - b.x, cby = c.y - b.y;
    final dot = abx * cbx + aby * cby;
    final mag =
        math.sqrt(abx * abx + aby * aby) * math.sqrt(cbx * cbx + cby * cby);
    if (mag == 0) return 180;
    return math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  /// Angle of the [upper]→[lower] segment away from vertical, in degrees.
  static double _leanFromVertical(PoseLandmark upper, PoseLandmark lower) {
    final dx = (upper.x - lower.x).abs();
    final dy = (upper.y - lower.y).abs();
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  static double _distance(PoseLandmark a, PoseLandmark b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  double _confidence(Map<String, PoseLandmark> joints) =>
      joints.values.fold<double>(0, (s, l) => s + l.confidence) / joints.length;

  FormFeedback _notVisible(String exercise, String parts) => FormFeedback(
    score: 0,
    confidence: 0,
    warnings: const [],
    corrections: [
      'Make sure your $parts are in view. ${SupportedMvpExercises.cameraTip(exercise)}',
    ],
    bodyVisible: false,
  );

  // ===========================================================================
  // 1. SQUAT
  // ===========================================================================
  FormFeedback _analyzeSquat(List<PoseLandmark> l, bool judgeDepth) {
    const needed = ['shoulder', 'hip', 'knee', 'ankle'];
    final j = _joints(l, _bestSide(l, needed), needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.squat,
        'shoulders, hips, knees and ankles',
      );
    }

    final knee = _angle(j['hip']!, j['knee']!, j['ankle']!);
    final lean = _leanFromVertical(j['shoulder']!, j['hip']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (judgeDepth) {
      if (knee <= 95) {
        positives.add('Great depth');
      } else if (knee <= 105) {
        positives.add('Good depth at parallel');
      } else if (knee < 140) {
        score -= 25;
        warnings.add('Squat deeper (depth too shallow)');
        corrections.add('Squat deeper to break parallel');
      }
    }
    if (knee >= 140) positives.add('Upright stance ready');

    // Torso lean from vertical. Low-bar squats lean ~45°; beyond 50° the chest
    // is collapsing.
    if (lean > 50) {
      score -= 20;
      warnings.add('Maintain upright chest (excessive forward lean)');
      corrections.add('Maintain upright chest throughout the movement');
    } else if (knee < 130) {
      positives.add('Maintain upright chest');
    }

    // Knee cave is only visible from the front: both hips, knees and ankles
    // in view and hips clearly apart.
    final lHip = _visible(l, PoseLandmarkNames.leftHip);
    final rHip = _visible(l, PoseLandmarkNames.rightHip);
    final lKnee = _visible(l, PoseLandmarkNames.leftKnee);
    final rKnee = _visible(l, PoseLandmarkNames.rightKnee);
    final lAnkle = _visible(l, PoseLandmarkNames.leftAnkle);
    final rAnkle = _visible(l, PoseLandmarkNames.rightAnkle);
    if (lHip != null &&
        rHip != null &&
        lKnee != null &&
        rKnee != null &&
        lAnkle != null &&
        rAnkle != null) {
      final torso = _distance(j['shoulder']!, j['hip']!);
      final facingCamera = torso > 0 && (lHip.x - rHip.x).abs() / torso > 0.35;
      if (facingCamera && knee < 140) {
        final kneeWidth = (lKnee.x - rKnee.x).abs();
        final ankleWidth = (lAnkle.x - rAnkle.x).abs();
        if (ankleWidth > 0 && kneeWidth < ankleWidth * 0.8) {
          score -= 20;
          warnings.add('Keep knees aligned (knees caving inward)');
          corrections.add(
            'Keep knees aligned and push knees outward in line with toes',
          );
        } else {
          positives.add('Stable knee tracking');
        }
      }
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // 2. BENCH PRESS
  // ===========================================================================
  FormFeedback _analyzeBenchPress(List<PoseLandmark> l, bool judgeDepth) {
    const needed = ['hip', 'shoulder', 'elbow', 'wrist'];
    final j = _joints(l, _bestSide(l, needed), needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.benchPress,
        'shoulders, elbows and wrists',
      );
    }

    final elbow = _angle(j['shoulder']!, j['elbow']!, j['wrist']!);
    // Upper arm angle away from the torso (shoulder abduction).
    final flare = _angle(j['hip']!, j['shoulder']!, j['elbow']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (judgeDepth) {
      if (elbow <= 90) {
        positives.add('Full range of motion achieved at chest level.');
      } else if (elbow > 105 && elbow < 140) {
        score -= 15;
        corrections.add('Lower the bar/weights fully to touch chest lightly.');
      }
    }

    if (elbow < 140) {
      if (flare > 75) {
        score -= 25;
        warnings.add(
          'Elbows flaring out at 90 degrees risking shoulder impingement.',
        );
        corrections.add(
          'Tuck elbows to approximately 45-60 degrees relative to your torso.',
        );
      } else {
        positives.add('Shoulder-safe tucked elbow path.');
      }
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // 3. BICEP CURL
  // ===========================================================================
  FormFeedback _analyzeBicepCurl(List<PoseLandmark> l, bool judgeDepth) {
    const needed = ['hip', 'shoulder', 'elbow', 'wrist'];
    final j = _joints(l, _bestSide(l, needed), needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.bicepCurl,
        'hips, shoulders, elbows and wrists',
      );
    }

    final elbow = _angle(j['shoulder']!, j['elbow']!, j['wrist']!);
    final lean = _leanFromVertical(j['shoulder']!, j['hip']!);
    final upperArm = _angle(j['hip']!, j['shoulder']!, j['elbow']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (judgeDepth) {
      if (elbow <= 55) {
        positives.add('Complete bicep peak contraction.');
      } else if (elbow <= 70) {
        positives.add('Good contraction.');
      }
    }

    if (lean > 15) {
      score -= 25;
      warnings.add('Torso swinging used for momentum.');
      corrections.add(
        'Pin elbows to your sides and brace core without rocking.',
      );
    } else {
      positives.add('Strict elbow isolation maintained.');
    }

    if (upperArm > 35) {
      score -= 10;
      corrections.add(
        'Keep your elbows by your sides; avoid lifting them forward.',
      );
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // 4. PUSH-UP
  // ===========================================================================
  FormFeedback _analyzePushUp(List<PoseLandmark> l, bool judgeDepth) {
    const needed = ['shoulder', 'elbow', 'wrist', 'hip', 'ankle'];
    final j = _joints(l, _bestSide(l, needed), needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.pushUp,
        'shoulders, hips and ankles',
      );
    }

    final elbow = _angle(j['shoulder']!, j['elbow']!, j['wrist']!);
    final bodyLine = _angle(j['shoulder']!, j['hip']!, j['ankle']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (judgeDepth) {
      if (elbow <= 90) {
        positives.add('Solid push-up depth at 90 degrees.');
      } else if (elbow > 105 && elbow < 150) {
        score -= 20;
        warnings.add('Incomplete push-up depth.');
        corrections.add('Lower chest to hover 1-2 inches above the floor.');
      }
    }

    if (bodyLine < 160) {
      // Is the hip below or above the shoulder–ankle line? (Image y grows down.)
      final s = j['shoulder']!, h = j['hip']!, a = j['ankle']!;
      final t = (a.x - s.x) == 0 ? 0.5 : (h.x - s.x) / (a.x - s.x);
      final lineY = s.y + t * (a.y - s.y);
      if (h.y > lineY) {
        score -= 25;
        warnings.add(
          'Hips sagging below bodyline putting strain on lower back.',
        );
        corrections.add(
          'Brace core and squeeze glutes to maintain a straight plank.',
        );
      } else {
        score -= 15;
        warnings.add('Hips piking up above bodyline.');
        corrections.add('Lower hips slightly to maintain level plank.');
      }
    } else {
      positives.add('Straight spine alignment.');
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // 5. DEADLIFT
  // ===========================================================================
  FormFeedback _analyzeDeadlift(List<PoseLandmark> l) {
    const needed = ['shoulder', 'hip', 'knee', 'ankle'];
    final side = _bestSide(l, needed);
    final j = _joints(l, side, needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.deadlift,
        'shoulders, hips, knees and ankles',
      );
    }

    final hip = _angle(j['shoulder']!, j['hip']!, j['knee']!);
    final knee = _angle(j['hip']!, j['knee']!, j['ankle']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (hip < 140 && knee > 100) {
      positives.add('Strong hip-hinge position with high hips.');
    } else if (knee < 85) {
      score -= 15;
      corrections.add(
        'Hips are too low; hinge more at hips rather than squatting.',
      );
    }

    if (hip >= 165 && knee >= 165) {
      positives.add('Clean lockout achieved at the top.');

      // Leaning back at lockout: shoulders behind hips, judged against the
      // direction the feet point (heel → toe).
      final heel = _visible(l, '${side}_heel');
      final toe = _visible(l, '${side}_foot_index');
      if (heel != null && toe != null && toe.x != heel.x) {
        final forward = (toe.x - heel.x).sign;
        final behind = (j['shoulder']!.x - j['hip']!.x) * forward < 0;
        if (behind && _leanFromVertical(j['shoulder']!, j['hip']!) > 15) {
          score -= 15;
          warnings.add('Leaning back at lockout.');
          corrections.add(
            'Finish tall: squeeze glutes and keep ribs down instead of leaning back.',
          );
        }
      }
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // 6. OVERHEAD PRESS
  // ===========================================================================
  FormFeedback _analyzeOverheadPress(List<PoseLandmark> l, bool judgeDepth) {
    const needed = ['hip', 'shoulder', 'elbow', 'wrist'];
    final j = _joints(l, _bestSide(l, needed), needed);
    if (j == null) {
      return _notVisible(
        SupportedMvpExercises.overheadPress,
        'hips, shoulders, elbows and wrists',
      );
    }

    final elbow = _angle(j['shoulder']!, j['elbow']!, j['wrist']!);
    final lean = _leanFromVertical(j['shoulder']!, j['hip']!);
    final wristAbove = j['wrist']!.y < j['shoulder']!.y;
    final torso = _distance(j['shoulder']!, j['hip']!);
    final warnings = <String>[];
    final corrections = <String>[];
    final positives = <String>[];
    var score = 100;

    if (wristAbove && elbow >= 160) {
      positives.add('Full lockout overhead.');
      final offset = torso == 0
          ? 0
          : (j['wrist']!.x - j['shoulder']!.x).abs() / torso;
      if (offset > 0.35) {
        score -= 10;
        corrections.add('Finish with wrists stacked over your shoulders.');
      } else {
        positives.add('Bar finishes stacked over shoulders.');
      }
    } else if (judgeDepth && wristAbove && elbow > 120) {
      score -= 15;
      corrections.add('Press to a full lockout overhead.');
    }

    // A small lean clears the face; more turns it into an incline press and
    // loads the lower back.
    if (lean > 15) {
      score -= 20;
      warnings.add('Leaning back to press.');
      corrections.add(
        'Squeeze glutes and brace; keep ribs down and torso upright.',
      );
    } else {
      positives.add('Upright, braced torso.');
    }

    return FormFeedback(
      score: score.clamp(0, 100),
      confidence: _confidence(j),
      warnings: warnings,
      corrections: corrections,
      positiveFeedback: positives,
    );
  }

  // ===========================================================================
  // REP COUNTER
  // ===========================================================================

  static const Map<String, _RepPattern> _patterns = {
    SupportedMvpExercises.squat: _RepPattern(true, 155, 100),
    SupportedMvpExercises.benchPress: _RepPattern(true, 155, 95),
    SupportedMvpExercises.pushUp: _RepPattern(true, 155, 95),
    SupportedMvpExercises.bicepCurl: _RepPattern(true, 140, 65),
    SupportedMvpExercises.deadlift: _RepPattern(false, 125, 165),
    SupportedMvpExercises.overheadPress: _RepPattern(false, 100, 160),
  };

  /// The joint angle that tracks progress through a rep.
  double? _primaryAngle(String exercise, List<PoseLandmark> l) {
    final List<String> joints;
    switch (exercise) {
      case SupportedMvpExercises.squat:
        joints = const ['hip', 'knee', 'ankle'];
      case SupportedMvpExercises.deadlift:
        joints = const ['shoulder', 'hip', 'knee'];
      default:
        joints = const ['shoulder', 'elbow', 'wrist'];
    }
    final j = _joints(l, _bestSide(l, joints), joints);
    if (j == null) return null;
    return _angle(j[joints[0]]!, j[joints[1]]!, j[joints[2]]!);
  }

  /// Advances the rep state machine with one frame. Frames where the primary
  /// joints are not visible are ignored.
  ///
  /// With [smooth] the followed angle is lightly smoothed first (live camera
  /// frames, which jitter). Uploaded videos keep the raw angle. The smoother
  /// starts again whenever the joints drop out of view.
  void updateRepCounter(
    String exercise,
    List<PoseLandmark> landmarks, {
    bool smooth = false,
  }) {
    final norm = SupportedMvpExercises.normalize(exercise);
    final pattern = _patterns[norm]!;
    var v = _primaryAngle(norm, landmarks);
    if (v == null) {
      if (smooth) _primarySmoother.reset();
      return;
    }
    if (smooth) v = _primarySmoother.smooth(v);

    // Work in a space where every rep goes high → low → high.
    final value = pattern.startsExtended ? v : 360 - v;
    final start = pattern.startsExtended ? pattern.start : 360 - pattern.start;
    final turn = pattern.startsExtended ? pattern.turn : 360 - pattern.turn;

    // A fast movement can cross several thresholds between two frames, so
    // keep stepping until the phase settles.
    for (var step = 0; step < 4; step++) {
      final before = _phase;
      switch (_phase) {
        case MovementPhase.ready:
          if (value < start - _repHysteresis) {
            _phase = MovementPhase.eccentric;
            _repExtreme = value;
          }
        case MovementPhase.eccentric:
          _repExtreme = math.min(_repExtreme ?? value, value);
          if (value <= turn) {
            _phase = MovementPhase.inflection;
          } else if (value >= start) {
            // Came back without reaching full range: a partial rep.
            _partialRepAngles.add(_toAngle(pattern, _repExtreme!));
            _repExtreme = null;
            _phase = MovementPhase.ready;
            return;
          }
        case MovementPhase.inflection:
          _repExtreme = math.min(_repExtreme ?? value, value);
          if (value > turn + _repHysteresis) _phase = MovementPhase.concentric;
        case MovementPhase.concentric:
          if (value >= start) {
            _completedReps++;
            _repTurnAngles.add(_toAngle(pattern, _repExtreme ?? value));
            _repExtreme = null;
            _phase = MovementPhase.ready;
            return;
          }
      }
      if (_phase == before) return;
    }
  }

  static double _toAngle(_RepPattern pattern, double value) =>
      pattern.startsExtended ? value : 360 - value;
}
