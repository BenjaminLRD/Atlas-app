import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/ai_form_coach/models/form_feedback.dart';
import 'package:atlas/ai_form_coach/models/pose_landmark.dart';
import 'package:atlas/ai_form_coach/services/angle_smoother.dart';
import 'package:atlas/ai_form_coach/services/feedback_throttle.dart';
import 'package:atlas/ai_form_coach/services/form_analysis_service.dart';

/// Left-side squat frame with the knee at [kneeAngle] degrees.
List<PoseLandmark> squatFrame(double kneeAngle) {
  const knee = (x: 0.5, y: 0.7);
  const length = 0.2;
  final rad = kneeAngle * math.pi / 180;
  PoseLandmark lm(String name, double x, double y) =>
      PoseLandmark(name: name, x: x, y: y, z: 0, confidence: 1.0);
  return [
    lm(
      PoseLandmarkNames.leftHip,
      knee.x + length * math.sin(rad),
      knee.y + length * math.cos(rad),
    ),
    lm(PoseLandmarkNames.leftKnee, knee.x, knee.y),
    lm(PoseLandmarkNames.leftAnkle, knee.x, knee.y + length),
  ];
}

int countReps(List<double> angles, {required bool smooth}) {
  final service = FormAnalysisService();
  service.reset(exercise: 'Squat');
  for (final a in angles) {
    service.updateRepCounter('Squat', squatFrame(a), smooth: smooth);
  }
  return service.completedReps;
}

List<double> repAngles() => const [
  170, 160, 145, 125, 105, 88, 85, 88, 105, 125, 145, 160, 170, //
];

FormFeedback fb({
  List<String> warnings = const [],
  List<String> corrections = const [],
  bool bodyVisible = true,
}) => FormFeedback(
  score: 80,
  warnings: warnings,
  corrections: corrections,
  bodyVisible: bodyVisible,
);

void main() {
  group('AngleSmoother', () {
    test('the first value passes through and later ones are blended', () {
      final s = AngleSmoother(alpha: 0.5);
      expect(s.smooth(100), 100);
      expect(s.smooth(200), 150);
      expect(s.smooth(200), 175);
      expect(s.frameCount, 3);
    });

    test('warm-up frames pass through unsmoothed', () {
      final s = AngleSmoother(alpha: 0.2, warmupFrames: 3);
      expect(s.smooth(100), 100);
      expect(s.smooth(160), 160); // frame 2: warm-up
      expect(s.smooth(40), 40); // frame 3: warm-up
      expect(s.smooth(140), closeTo(0.2 * 140 + 0.8 * 40, 1e-9));
    });

    test('reset starts the filter again', () {
      final s = AngleSmoother(alpha: 0.5)..smooth(100);
      s.reset();
      expect(s.isInitialized, isFalse);
      expect(s.smooth(30), 30);
    });

    test('invalid settings are rejected', () {
      expect(() => AngleSmoother(alpha: 1.1), throwsArgumentError);
      expect(() => AngleSmoother(alpha: -0.1), throwsArgumentError);
      expect(() => AngleSmoother(warmupFrames: -1), throwsArgumentError);
    });
  });

  group('rep counting with noisy angles', () {
    test('a clean rep counts once, smoothed or not', () {
      expect(countReps(repAngles(), smooth: false), 1);
      expect(countReps(repAngles(), smooth: true), 1);
    });

    test('a single-frame spike is a false rep without smoothing and is '
        'ignored with it', () {
      final standing = List<double>.filled(5, 170);
      final withSpike = [...standing, 60.0, ...standing];
      expect(countReps(withSpike, smooth: false), 1);
      expect(countReps(withSpike, smooth: true), 0);
    });

    test('three real reps with jitter on every frame still count as three', () {
      final random = math.Random(7);
      final angles = <double>[];
      for (var rep = 0; rep < 3; rep++) {
        for (final a in repAngles()) {
          angles.add(a + (random.nextDouble() * 12 - 6));
        }
        angles.addAll(List<double>.filled(4, 170));
      }
      expect(countReps(angles, smooth: true), 3);
    });

    test('a real rep with a held bottom still reaches full depth', () {
      final angles = [
        ...repAngles().take(6),
        ...List<double>.filled(4, 90),
        ...repAngles().skip(7),
      ];
      expect(countReps(angles, smooth: true), 1);
    });

    test(
      'smoothing is off by default, so uploaded videos behave as before',
      () {
        final service = FormAnalysisService()..reset(exercise: 'Squat');
        final standing = List<double>.filled(5, 170);
        for (final a in [...standing, 60.0, ...standing]) {
          service.updateRepCounter('Squat', squatFrame(a));
        }
        expect(service.completedReps, 1);
      },
    );

    test('reset clears the smoother, so a new set does not start from the old '
        'angle', () {
      final service = FormAnalysisService()..reset(exercise: 'Squat');
      // Smoother history ends deep in a squat.
      for (var i = 0; i < 6; i++) {
        service.updateRepCounter('Squat', squatFrame(60), smooth: true);
      }

      service.reset(exercise: 'Squat');
      // A stale smoother would drag the first standing frames down to about
      // 126 degrees, which starts a descent and records a partial rep.
      for (var i = 0; i < 6; i++) {
        service.updateRepCounter('Squat', squatFrame(170), smooth: true);
      }

      expect(service.currentPhase, MovementPhase.ready);
      expect(service.partialRepAngles, isEmpty);
      expect(service.completedReps, 0);
    });

    test('losing the joints restarts the smoothing and does not crash', () {
      final service = FormAnalysisService()..reset(exercise: 'Squat');
      for (final a in repAngles()) {
        service.updateRepCounter('Squat', squatFrame(a), smooth: true);
      }
      service.updateRepCounter('Squat', const [], smooth: true);
      for (final a in repAngles()) {
        service.updateRepCounter('Squat', squatFrame(a), smooth: true);
      }
      expect(service.completedReps, 2);
    });
  });

  group('FormCueThrottle', () {
    late DateTime now;
    late FormCueThrottle throttle;

    setUp(() {
      now = DateTime(2026, 10, 20, 12);
      throttle = FormCueThrottle(clock: () => now);
    });

    void advance(double seconds) =>
        now = now.add(Duration(milliseconds: (seconds * 1000).round()));

    test('safety-critical faults are shown at once and never throttled', () {
      expect(
        throttle.update(fb(corrections: ['Lower the bar fully'])),
        'Lower the bar fully',
      );
      advance(0.1);
      expect(
        throttle.update(
          fb(warnings: ['Rounded back'], corrections: ['Brace your core']),
        ),
        'Brace your core',
      );
      advance(0.1);
      expect(
        throttle.update(
          fb(warnings: ['Knees caving'], corrections: ['Push knees out']),
        ),
        'Push knees out',
      );
      advance(0.1);
      expect(
        throttle.update(
          fb(warnings: ['Rounded back'], corrections: ['Brace your core']),
        ),
        'Brace your core',
      );
    });

    test('a fault with no correction text uses the warning', () {
      expect(throttle.update(fb(warnings: ['Hips sagging'])), 'Hips sagging');
    });

    test('guidance cannot change the cue inside the global cooldown', () {
      expect(throttle.update(fb(corrections: ['A'])), 'A');
      advance(1.0);
      expect(throttle.update(fb(corrections: ['B'])), 'A');
      advance(1.5); // 2.5 s since A
      expect(throttle.update(fb(corrections: ['B'])), 'B');
    });

    test('the same guidance stays on screen while it lasts', () {
      expect(throttle.update(fb(corrections: ['A'])), 'A');
      advance(10);
      expect(throttle.update(fb(corrections: ['A'])), 'A');
      advance(10);
      expect(throttle.update(fb(corrections: ['A'])), 'A');
    });

    test('a cue just shown is not shown again inside its own cooldown', () {
      expect(throttle.update(fb(corrections: ['A'])), 'A');
      advance(0.5);
      expect(throttle.update(fb()), isNull); // nothing to correct
      advance(1.6); // 2.1 s since A: global cooldown is over
      expect(throttle.update(fb(corrections: ['B'])), 'B');
      advance(0.5); // 0.5 s since B: global cooldown still on
      expect(throttle.update(fb()), isNull);
      advance(1.6); // 2.1 s after B, 4.2 s after A
      expect(throttle.update(fb(corrections: ['A'])), 'A');
      advance(0.2);
      expect(throttle.update(fb()), isNull);
      advance(2.1); // global over, but A was shown 2.3 s ago (< 3 s)
      expect(throttle.update(fb(corrections: ['A'])), isNull);
      advance(1.0); // 3.3 s since A
      expect(throttle.update(fb(corrections: ['A'])), 'A');
    });

    test('a frame with nothing to correct clears the cue at once', () {
      throttle.update(fb(corrections: ['A']));
      expect(throttle.update(fb()), isNull);
      expect(throttle.currentCue, isNull);
    });

    test('a fault cue is dropped as soon as the fault is gone', () {
      throttle.update(
        fb(warnings: ['Rounded back'], corrections: ['Brace your core']),
      );
      advance(0.1);
      // Fault fixed; new guidance is still inside the global cooldown.
      expect(throttle.update(fb(corrections: ['Lower the bar fully'])), isNull);
      expect(throttle.currentCue, isNull);
      advance(2.0);
      expect(
        throttle.update(fb(corrections: ['Lower the bar fully'])),
        'Lower the bar fully',
      );
    });

    test('frames where the body is not visible change nothing', () {
      throttle.update(fb(corrections: ['A']));
      expect(throttle.update(fb(bodyVisible: false)), 'A');
      expect(throttle.currentCue, 'A');
    });

    test('safety-critical means a visible frame with a warning', () {
      expect(FormCueThrottle.isSafetyCritical(fb(warnings: ['x'])), isTrue);
      expect(FormCueThrottle.isSafetyCritical(fb(corrections: ['x'])), isFalse);
      expect(
        FormCueThrottle.isSafetyCritical(
          fb(warnings: ['x'], bodyVisible: false),
        ),
        isFalse,
      );
    });

    test('reset forgets the history', () {
      throttle.update(fb(corrections: ['A']));
      throttle.reset();
      expect(throttle.currentCue, isNull);
      expect(throttle.update(fb(corrections: ['B'])), 'B');
    });
  });
}
