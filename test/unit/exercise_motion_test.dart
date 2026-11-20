import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise/exercise_motion.dart';
import 'package:atlas/widgets/exercise/exercise_motion_view.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';

double _len(Offset a, Offset b) => (a - b).distance;

void _expectLen(
  String id,
  double t,
  String what,
  Offset a,
  Offset b,
  double l,
) {
  expect(
    _len(a, b),
    closeTo(l, 0.03),
    reason: '$id t=$t: $what length drifted',
  );
}

void main() {
  final catalogue = Exercise.defaultRegistry();

  group('Catalogue coverage is stated honestly', () {
    test(
      'every catalogue exercise is either animated or flagged with a reason',
      () {
        for (final e in catalogue) {
          final animated = ExerciseMotions.has(e.id);
          final reason = ExerciseMotions.unavailableReason(e.id);
          expect(
            animated || (reason != null && reason.isNotEmpty),
            isTrue,
            reason: '${e.id} is neither animated nor flagged',
          );
          expect(
            animated && reason != null,
            isFalse,
            reason: '${e.id} is both animated and flagged',
          );
        }
      },
    );

    test('counts match what is reported', () {
      final animated = catalogue.where((e) => ExerciseMotions.has(e.id));
      final flagged = catalogue.where(
        (e) => ExerciseMotions.unavailableReason(e.id) != null,
      );
      expect(catalogue.length, 72);
      expect(animated.length, 63);
      expect(flagged.length, 9);
    });

    test('animations and flags only refer to real catalogue ids', () {
      final ids = catalogue.map((e) => e.id).toSet();
      for (final m in ExerciseMotions.all) {
        expect(ids.contains(m.id), isTrue, reason: '${m.id} not in catalogue');
      }
      for (final id in ExerciseMotions.unavailable.keys) {
        expect(ids.contains(id), isTrue, reason: '$id flag not in catalogue');
      }
    });

    test('titles match the catalogue exercise names', () {
      for (final m in ExerciseMotions.all) {
        final e = Exercise.getById(m.id)!;
        expect(m.title, e.name, reason: m.id);
        expect(m.cue.trim(), isNotEmpty, reason: '${m.id} has no cue');
      }
    });
  });

  group('Kinematic validity', () {
    test('limbs keep their length, reach their holds, never NaN', () {
      for (final m in ExerciseMotions.all) {
        for (var i = 0; i <= 20; i++) {
          final t = i / 20;
          final p = m.pose(t);
          final pts = [
            p.hip,
            p.knee,
            p.ankle,
            p.heel,
            p.toe,
            p.shoulder,
            p.elbow,
            p.wrist,
            p.head,
            p.focus,
          ];
          for (final o in pts) {
            expect(
              o.dx.isFinite && o.dy.isFinite,
              isTrue,
              reason: '${m.id} $t',
            );
          }
          // Arms swing in the picture plane in every view. Legs and trunk are
          // true lengths only in the side view (the others foreshorten them).
          _expectLen(m.id, t, 'upper arm', p.shoulder, p.elbow, kUpperArm);
          _expectLen(m.id, t, 'forearm', p.elbow, p.wrist, kForeArm);
          if (p.farElbow != null && p.farWrist != null) {
            final fs = p.farShoulder ?? p.shoulder;
            _expectLen(m.id, t, 'far upper arm', fs, p.farElbow!, kUpperArm);
            _expectLen(
              m.id,
              t,
              'far forearm',
              p.farElbow!,
              p.farWrist!,
              kForeArm,
            );
          }
          if (m.view == MotionView.side) {
            _expectLen(m.id, t, 'thigh', p.hip, p.knee, kThigh);
            _expectLen(m.id, t, 'shin', p.knee, p.ankle, kShin);
            _expectLen(m.id, t, 'trunk', p.hip, p.shoulder, kTrunk);
            if (p.farKnee != null && p.farAnkle != null) {
              _expectLen(m.id, t, 'far thigh', p.hip, p.farKnee!, kThigh);
              _expectLen(m.id, t, 'far shin', p.farKnee!, p.farAnkle!, kShin);
            }
          }
          expect(
            p.reachError,
            lessThan(0.03),
            reason: '${m.id} t=$t: a planted hand/foot is out of reach',
          );
        }
      }
    });

    test('the body never sinks through the floor', () {
      for (final m in ExerciseMotions.all.where(
        (m) => m.view != MotionView.top,
      )) {
        for (var i = 0; i <= 20; i++) {
          final p = m.pose(i / 20);
          for (final o in [p.ankle, p.toe, p.heel, p.knee, p.hip]) {
            expect(o.dy, greaterThan(-0.12), reason: '${m.id} t=${i / 20}');
          }
        }
      }
    });

    test('cyclic motions close their loop', () {
      for (final m in ExerciseMotions.all.where((m) => m.cyclic)) {
        final a = m.pose(0);
        final b = m.pose(1);
        expect(_len(a.hip, b.hip), lessThan(0.06), reason: m.id);
        expect(_len(a.wrist, b.wrist), lessThan(0.06), reason: m.id);
      }
    });

    test('motion actually moves (not a still frame) unless isometric', () {
      for (final m in ExerciseMotions.all.where((m) => !m.isometric)) {
        var travel = 0.0;
        var prev = m.pose(0);
        for (var i = 1; i <= 20; i++) {
          final p = m.pose(i / 20);
          travel +=
              _len(p.wrist, prev.wrist) +
              _len(p.hip, prev.hip) +
              _len(p.knee, prev.knee) +
              _len(p.ankle, prev.ankle) +
              _len(p.heel, prev.heel);
          final s0 = prev.spine, s1 = p.spine;
          if (s0 != null && s1 != null) {
            for (var j = 0; j < s0.length; j++) {
              travel += _len(s0[j], s1[j]);
            }
          }
          prev = p;
        }
        expect(travel, greaterThan(0.05), reason: '${m.id} barely moves');
      }
    });

    test('bounds are finite and non-empty', () {
      for (final m in ExerciseMotions.all) {
        final r = motionBounds(m);
        expect(r.width > 0.3 && r.height > 0.3, isTrue, reason: m.id);
      }
    });
  });

  group('Viewpoint selection', () {
    test('movements across the body use a front, foot-end or top view', () {
      MotionView v(String id) => ExerciseMotions.forId(id)!.view;
      expect(v('lateral_raise'), MotionView.front);
      expect(v('cable_lateral_raise'), MotionView.front);
      expect(v('rear_delt_fly'), MotionView.front);
      expect(v('dumbbell_chest_fly'), MotionView.front);
      expect(
        ExerciseMotions.forId('dumbbell_chest_fly')!.viewLabel,
        contains('foot of the bench'),
      );
      expect(v('cable_chest_fly'), MotionView.top);
      expect(v('barbell_back_squat'), MotionView.side);
      expect(v('chest_dips'), MotionView.side);
      expect(v('face_pulls'), MotionView.side);
    });

    test('every non-side view says what the viewer is looking at', () {
      for (final m in ExerciseMotions.all.where(
        (m) => m.view != MotionView.side,
      )) {
        expect(m.viewLabel, isNot('Side view'), reason: m.id);
      }
    });

    test(
      'walking and running travel, so feet are not sliding on a still floor',
      () {
        for (final id in [
          'walking_lunges',
          'outdoor_run',
          'treadmill_run',
          'sprint_intervals',
          'jogging',
        ]) {
          final m = ExerciseMotions.forId(id)!;
          expect(m.travelPerCycle, isNotNull, reason: id);
          expect(
            m.pose(0.9).travel,
            greaterThan(m.pose(0.1).travel),
            reason: id,
          );
        }
      },
    );

    test('a planted foot stays fixed on the ground while the body moves', () {
      // Running: while a foot is on the ground (first 40% of its cycle) its
      // position relative to the ground (body position minus travel) is fixed.
      final m = ExerciseMotions.forId('outdoor_run')!;
      double worldX(double d) {
        final p = m.pose(d);
        return p.ankle.dx + p.travel;
      }

      final a = worldX(0.05);
      for (final d in [0.1, 0.2, 0.3, 0.38]) {
        expect(worldX(d), closeTo(a, 0.02), reason: 'd=$d');
      }
    });
  });

  group('Player integration', () {
    Future<void> pumpPlayer(
      WidgetTester t,
      Exercise e, {
      double w = 360,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: w,
                child: ExerciseVideoPlayer(
                  exercise: e,
                  autoPlay: false,
                  showControls: true,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('animated exercise shows the animation first', (t) async {
      await pumpPlayer(t, Exercise.getById('barbell_back_squat')!);
      expect(find.text('FORM ANIMATION'), findsOneWidget);
      expect(find.byType(ExerciseMotionView), findsOneWidget);
    });

    testWidgets('every animated exercise renders on a narrow phone', (t) async {
      for (final m in ExerciseMotions.all) {
        await pumpPlayer(t, Exercise.getById(m.id)!, w: 280);
        expect(t.takeException(), isNull, reason: m.id);
        expect(find.byType(ExerciseMotionView), findsOneWidget, reason: m.id);
      }
    });

    testWidgets('flagged exercise without media says why', (t) async {
      final id = ExerciseMotions.unavailable.keys.firstWhere(
        (k) =>
            (Exercise.getById(k)!.videoUrl ?? '').isEmpty &&
            (Exercise.getById(k)!.imageUrl ?? '').isEmpty,
        orElse: () => '',
      );
      if (id.isEmpty) return;
      await pumpPlayer(t, Exercise.getById(id)!);
      expect(find.byType(ExerciseMotionView), findsNothing);
      expect(find.byKey(const Key('no_demonstration')), findsOneWidget);
      expect(find.byKey(const Key('no_demonstration_reason')), findsOneWidget);
    });

    testWidgets('the YouTube video is offered on iOS and on Android', (
      t,
    ) async {
      // A YouTube link opens in the YouTube app or the browser, so unlike the
      // old WebM clips it does not depend on what the platform can decode.
      final e = Exercise.getById('barbell_back_squat')!;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpPlayer(t, e);
        expect(find.byKey(const Key('form_mode_video')), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      await pumpPlayer(t, e);
      expect(find.byKey(const Key('form_mode_video')), findsOneWidget);
    });

    testWidgets('reduced motion renders a still frame, no endless ticker', (
      t,
    ) async {
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseMotionView(
                motion: ExerciseMotions.forId('barbell_back_squat')!,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(ExerciseMotionView), findsOneWidget);
    });
  });
}
