import 'package:atlas/app_theme.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise/exercise_motion.dart';
import 'package:atlas/widgets/exercise/exercise_motion_view.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _len(Offset a, Offset b) => (a - b).distance;

void main() {
  final twoView = [
    for (final m in ExerciseMotions.all)
      if (ExerciseMotions.viewsFor(m.id).length > 1) m.id,
  ];

  group('Alternate viewpoints', () {
    test('some exercises really have both a side and a front view', () {
      expect(twoView.length, 12);
      for (final id in [
        'barbell_back_squat',
        'bodyweight_squat',
        'overhead_press',
        'dumbbell_shoulder_press',
        'bicep_curl',
        'conventional_deadlift',
      ]) {
        expect(twoView, contains(id));
        expect(ExerciseMotions.availableViews(id), [
          MotionView.side,
          MotionView.front,
        ]);
      }
    });

    test('exercises with one drawn view offer exactly one', () {
      for (final id in [
        'plank',
        'lateral_raise',
        'cable_chest_fly',
        'walking_lunges',
        'chest_dips',
      ]) {
        expect(ExerciseMotions.viewsFor(id).length, 1, reason: id);
      }
      expect(ExerciseMotions.viewsFor('arnold_press'), isEmpty);
      expect(ExerciseMotions.viewsFor('no_such_exercise'), isEmpty);
      expect(ExerciseMotions.forIdView('plank', MotionView.front), isNull);
      expect(
        ExerciseMotions.forIdView('barbell_back_squat', MotionView.front),
        isNotNull,
      );
    });

    test('the right renderer is chosen for each view', () {
      for (final id in twoView) {
        final side = ExerciseMotions.forIdView(id, MotionView.side)!;
        final front = ExerciseMotions.forIdView(id, MotionView.front)!;
        expect(side.view, MotionView.side, reason: id);
        expect(front.view, MotionView.front, reason: id);
        expect(front.viewLabel, 'Front view', reason: id);
        expect(front.projectedFrom, id, reason: id);
        expect(identical(side, front), isFalse, reason: id);
        // The default stays the side view.
        expect(ExerciseMotions.forId(id)!.view, MotionView.side, reason: id);
      }
    });

    test('the front view shows the same movement as the side view', () {
      for (final id in twoView) {
        final side = ExerciseMotions.forIdView(id, MotionView.side)!;
        final front = ExerciseMotions.forIdView(id, MotionView.front)!;
        for (var i = 0; i <= 20; i++) {
          final d = i / 20;
          final s = side.pose(d), f = front.pose(d);
          // Same heights, because a front view only adds the sideways axis.
          expect(f.hip.dy, closeTo(s.hip.dy, 1e-9), reason: '$id hip $d');
          expect(f.knee.dy, closeTo(s.knee.dy, 1e-9), reason: '$id knee $d');
          expect(f.ankle.dy, closeTo(s.ankle.dy, 1e-9), reason: '$id ank $d');
          expect(f.shoulder.dy, closeTo(s.shoulder.dy, 1e-9), reason: id);
          expect(f.head.dy, closeTo(s.head.dy, 1e-9), reason: '$id head $d');
          // Left and right mirror each other.
          expect(f.farKnee!.dx, closeTo(-f.knee.dx, 1e-9), reason: id);
          expect(f.farWrist!.dx, closeTo(-f.wrist.dx, 1e-9), reason: id);
          expect(f.farWrist!.dy, closeTo(f.wrist.dy, 1e-9), reason: id);
          // A projection never makes a limb longer than the real bone
          // (small allowance for the sideways stance).
          void atMost(String n, Offset a, Offset b, double len) => expect(
            _len(a, b),
            lessThanOrEqualTo(len * 1.05),
            reason: '$id $n at $d',
          );
          atMost('thigh', f.hip, f.knee, kThigh);
          atMost('shin', f.knee, f.ankle, kShin);
          atMost('upper arm', f.shoulder, f.elbow, kUpperArm);
          atMost('forearm', f.elbow, f.wrist, kForeArm);
          expect(f.reachError, lessThan(0.03), reason: '$id $d');
        }
      }
    });
  });

  group('View toggle in the player', () {
    Widget host(Exercise e) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(child: ExerciseVideoPlayer(exercise: e)),
      ),
    );

    testWidgets('an exercise with two views can switch between them', (
      tester,
    ) async {
      final e = Exercise.getById('barbell_back_squat')!;
      await tester.pumpWidget(host(e));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('view_toggle_side')), findsOneWidget);
      expect(find.byKey(const Key('view_toggle_front')), findsOneWidget);
      expect(find.text('Side view'), findsOneWidget);

      final before = tester.state(find.byType(ExerciseMotionView));
      await tester.tap(find.byKey(const Key('view_toggle_front')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Front view'), findsWidgets);
      expect(find.text('Side view'), findsNothing);
      // The same animation continues; it is not restarted.
      expect(
        identical(tester.state(find.byType(ExerciseMotionView)), before),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('view_toggle_side')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Side view'), findsOneWidget);
    });

    testWidgets('an exercise with one view shows no toggle', (tester) async {
      for (final id in ['plank', 'lateral_raise', 'cable_chest_fly']) {
        await tester.pumpWidget(host(Exercise.getById(id)!));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ExerciseMotionView), findsOneWidget, reason: id);
        expect(find.byKey(const Key('view_toggle_side')), findsNothing);
        expect(find.byKey(const Key('view_toggle_front')), findsNothing);
        expect(find.byKey(const Key('view_toggle_top')), findsNothing);
      }
    });
  });
}
