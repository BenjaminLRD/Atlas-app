import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/ai_form_coach/models/pose_landmark.dart';
import 'package:atlas/ai_form_coach/services/form_analysis_service.dart';

PoseLandmark _lm(String name, double x, double y, {double c = 1.0}) =>
    PoseLandmark(name: name, x: x, y: y, z: 0, confidence: c);

/// A side-on body with the given joint positions on the left side.
List<PoseLandmark> _left(Map<String, List<double>> joints) => [
  for (final e in joints.entries) _lm('left_${e.key}', e.value[0], e.value[1]),
];

/// Same joints on the right side, with the left side barely visible.
List<PoseLandmark> _rightOnly(Map<String, List<double>> joints) => [
  for (final e in joints.entries) ...[
    _lm('right_${e.key}', e.value[0], e.value[1]),
    _lm('left_${e.key}', 0.0, 0.0, c: 0.1),
  ],
];

/// Squat frame with the given knee angle, built from hip/knee/ankle geometry.
Map<String, List<double>> _squat({required bool bottom}) => bottom
    ? {
        'shoulder': [0.50, 0.45],
        'hip': [0.50, 0.72],
        'knee': [0.35, 0.72],
        'ankle': [0.35, 0.92],
      }
    : {
        'shoulder': [0.50, 0.30],
        'hip': [0.50, 0.52],
        'knee': [0.50, 0.72],
        'ankle': [0.50, 0.92],
      };

void main() {
  late FormAnalysisService service;

  setUp(() {
    service = FormAnalysisService();
    service.reset(exercise: 'Squat');
  });

  group('Overhead press', () {
    test('is recognised under its common names', () {
      for (final name in [
        'Overhead Press',
        'Dumbbell Shoulder Press',
        'Military Press',
        'OHP',
      ]) {
        expect(SupportedMvpExercises.isSupported(name), isTrue, reason: name);
        expect(
          SupportedMvpExercises.normalize(name),
          SupportedMvpExercises.overheadPress,
        );
      }
    });

    test('praises a stacked, upright lockout', () {
      final feedback = service.analyzeFrame(
        exerciseName: 'Overhead Press',
        landmarks: _left({
          'hip': [0.50, 0.60],
          'shoulder': [0.50, 0.30],
          'elbow': [0.50, 0.18],
          'wrist': [0.50, 0.06],
        }),
      );
      expect(feedback.positiveFeedback, contains('Full lockout overhead.'));
      expect(feedback.warnings, isEmpty);
    });

    test('flags leaning back to press', () {
      final feedback = service.analyzeFrame(
        exerciseName: 'Overhead Press',
        landmarks: _left({
          'hip': [0.50, 0.60],
          'shoulder': [0.62, 0.32],
          'elbow': [0.62, 0.20],
          'wrist': [0.62, 0.08],
        }),
      );
      expect(feedback.warnings, contains('Leaning back to press.'));
    });

    test('counts a rep from the rack position to lockout and back', () {
      service.reset(exercise: 'Overhead Press');
      final racked = _left({
        'hip': [0.50, 0.60],
        'shoulder': [0.50, 0.30],
        'elbow': [0.58, 0.38],
        'wrist': [0.56, 0.24],
      });
      final lockout = _left({
        'hip': [0.50, 0.60],
        'shoulder': [0.50, 0.30],
        'elbow': [0.50, 0.18],
        'wrist': [0.50, 0.06],
      });
      for (final frame in [racked, lockout, racked]) {
        service.updateRepCounter('Overhead Press', frame);
      }
      expect(service.completedReps, 1);
    });
  });

  group('Rep counting', () {
    test('deadlift counts floor → lockout → floor (was never counted)', () {
      service.reset(exercise: 'Deadlift');
      final floor = _left({
        'shoulder': [0.35, 0.45],
        'hip': [0.55, 0.55],
        'knee': [0.50, 0.72],
        'ankle': [0.50, 0.92],
      });
      final lockout = _left({
        'shoulder': [0.50, 0.25],
        'hip': [0.50, 0.52],
        'knee': [0.50, 0.72],
        'ankle': [0.50, 0.92],
      });
      for (final frame in [floor, lockout, floor]) {
        service.updateRepCounter('Deadlift', frame);
      }
      expect(service.completedReps, 1);
    });

    test('push-ups are counted from the elbow, not the knee', () {
      service.reset(exercise: 'Push-up');
      final top = _left({
        'shoulder': [0.30, 0.50],
        'elbow': [0.30, 0.62],
        'wrist': [0.30, 0.74],
      });
      final bottom = _left({
        'shoulder': [0.30, 0.66],
        'elbow': [0.42, 0.66],
        'wrist': [0.42, 0.74],
      });
      for (final frame in [top, bottom, top]) {
        service.updateRepCounter('Push-up', frame);
      }
      expect(service.completedReps, 1);
    });

    test(
      'a rep that turns back early is not counted and gets depth feedback',
      () {
        final halfway = _left({
          'shoulder': [0.50, 0.40],
          'hip': [0.50, 0.60],
          'knee': [0.40, 0.70],
          'ankle': [0.40, 0.92],
        });
        for (final frame in [
          _left(_squat(bottom: false)),
          halfway,
          _left(_squat(bottom: false)),
        ]) {
          service.updateRepCounter('Squat', frame);
        }
        expect(service.completedReps, 0);
        expect(service.partialRepAngles, hasLength(1));
        expect(
          service.depthFeedbackForRep('Squat', service.partialRepAngles.single),
          contains('Squat deeper'),
        );
      },
    );

    test('uses the right side when the left is hidden from the camera', () {
      for (final bottom in [false, true, false]) {
        service.updateRepCounter('Squat', _rightOnly(_squat(bottom: bottom)));
      }
      expect(service.completedReps, 1);
    });

    test('frames without the needed joints do not change the count', () {
      service.updateRepCounter('Squat', _left(_squat(bottom: false)));
      service.updateRepCounter('Squat', const []);
      expect(service.currentPhase, MovementPhase.ready);
    });
  });

  test('works the same with pixel coordinates (video frames)', () {
    List<PoseLandmark> scaled(List<PoseLandmark> frame) => [
      for (final l in frame) _lm(l.name, l.x * 1080, l.y * 1920),
    ];
    final curlSwing = _left({
      'shoulder': [0.28, 0.30],
      'hip': [0.45, 0.60],
      'elbow': [0.38, 0.45],
      'wrist': [0.38, 0.25],
    });
    final normalised = service.analyzeFrame(
      exerciseName: 'Bicep Curl',
      landmarks: curlSwing,
    );
    final pixels = service.analyzeFrame(
      exerciseName: 'Bicep Curl',
      landmarks: scaled(curlSwing),
    );
    expect(pixels.score, normalised.score);
    expect(pixels.warnings, normalised.warnings);
  });

  test('a set with no visible body reports no score and no invented reps', () {
    final analysis = service.analyzeSet(
      exerciseName: 'Squat',
      frames: [const [], const []],
    );
    expect(analysis.repCount, 0);
    expect(analysis.formScore, 0);
    expect(analysis.feedback.bodyVisible, isFalse);
  });
}
