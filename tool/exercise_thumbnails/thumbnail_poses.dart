import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:atlas/services/exercise/exercise_motion.dart';

import 'figure_painter.dart';

/// Everything needed to draw one exercise's thumbnail.
class ThumbSpec {
  final MotionDef motion;
  final Pose pose;
  final List<Prop> extra;
  final List<ThumbDecor> behind;
  final List<ThumbDecor> front;
  final bool floor;
  final List<Offset> fitPoints;
  final bool towers;
  const ThumbSpec(
    this.motion,
    this.pose, {
    this.extra = const [],
    this.behind = const [],
    this.front = const [],
    this.floor = true,
    this.fitPoints = const [],
    this.towers = true,
  });
}

/// The frame of the movement that shows the exercise best (0 = start of the
/// first half, 1 = its end). Most use [_defaultD]; the rest are listed here
/// after looking at the contact sheet.
const double _defaultD = 0.88;
const Map<String, double> _frameOverrides = {
  // Pull-ups and chin-ups move the same way; show different moments so the
  // two thumbnails are not the same picture.
  'pull_ups': 0.55,
  'chin_ups': 1.0,
  // Sprint rowing is shown mid-drive with speed lines; the steady row at the
  // finish.
  'rowing_intervals': 0.35,
};

ThumbSpec thumbSpecFor(String id) {
  final motion = ExerciseMotions.forId(id);
  if (motion != null) {
    final d =
        _frameOverrides[id] ??
        (motion.isometric ? 0.5 : (motion.cyclic ? 0.15 : _defaultD));
    final deco = _decor[id];
    var pose = motion.pose(d);
    if (deco?.keepProp != null) {
      pose = pose.withProps([
        for (final p in pose.props)
          if (deco!.keepProp!(p)) p,
      ]);
    }
    return ThumbSpec(
      motion,
      pose,
      extra: deco?.extra(pose) ?? const [],
      behind: deco?.behind ?? const [],
      front: deco?.front ?? const [],
      towers: deco?.towers ?? true,
    );
  }
  final stat = _staticSpecs[id];
  if (stat == null) {
    throw StateError('No thumbnail pose for $id');
  }
  return stat();
}

/// Equipment drawn around an animated exercise's figure.
class _Decor {
  final List<Prop> Function(Pose pose)? extraProps;
  final bool Function(Prop prop)? keepProp;
  final List<ThumbDecor> behind;
  final List<ThumbDecor> front;
  final bool towers;
  const _Decor({
    this.extraProps,
    this.keepProp,
    this.behind = const [],
    this.front = const [],
    this.towers = true,
  });
  List<Prop> extra(Pose p) => extraProps == null ? const [] : extraProps!(p);
}

bool _isWheel(Prop p) =>
    p.kind == PropKind.circle && !p.filled && p.radius > 0.2;

void _hills(Canvas c, Offset Function(Offset) p, double s) {
  final base = p(Offset.zero).dy;
  final path = Path()
    ..moveTo(0, base)
    ..lineTo(0, base - 60)
    ..quadraticBezierTo(70, base - 118, 150, base - 52)
    ..quadraticBezierTo(220, base - 100, 290, base - 46)
    ..quadraticBezierTo(330, base - 70, 360, base - 40)
    ..lineTo(360, base)
    ..close();
  c.drawPath(
    path,
    Paint()..color = FigurePainter.emerald.withValues(alpha: 0.10),
  );
}

void _speedLines(Canvas c, Offset Function(Offset) p, double s) {
  final paint = Paint()
    ..color = FigurePainter.emerald.withValues(alpha: 0.75)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;
  for (final (y, len) in [(1.45, 0.34), (1.05, 0.46), (0.65, 0.30)]) {
    c.drawLine(p(Offset(-0.62 - len, y)), p(Offset(-0.62, y)), paint);
  }
}

final Map<String, _Decor> _decor = {
  // A hammer grip turns the dumbbell so its handle points forward: from the
  // side it shows as a bar with a weight at each end instead of one disc.
  'hammer_curl': _Decor(
    keepProp: (p) => false,
    extraProps: (p) => [
      Prop.line(
        p.wrist + const Offset(-0.10, 0),
        p.wrist + const Offset(0.10, 0),
      ),
      Prop.circle(p.wrist + const Offset(-0.10, 0), 0.055),
      Prop.circle(p.wrist + const Offset(0.10, 0), 0.055),
    ],
  ),
  // A barbell curl is seen from the side as a plate on the bar, not the small
  // dumbbell head of the dumbbell curls.
  'barbell_bicep_curl': _Decor(
    keepProp: (p) => false,
    extraProps: (p) => [Prop.circle(p.wrist, 0.14)],
  ),
  'rowing_machine': const _Decor(towers: false),
  'rowing_intervals': const _Decor(towers: false, front: [_speedLines]),
  'outdoor_run': const _Decor(behind: [_hills]),
  'outdoor_cycling': _Decor(behind: const [_hills], towers: false),
  'jogging': const _Decor(behind: [_hills]),
  'sprint_intervals': const _Decor(front: [_speedLines]),
  'treadmill_run': _Decor(
    extraProps: (p) => [
      Prop.rect(const Offset(-0.80, -0.03), const Offset(0.80, 0.05)),
      Prop.rect(const Offset(0.80, 0.0), const Offset(0.88, 1.18)),
      Prop.rect(const Offset(0.62, 1.05), const Offset(0.96, 1.30)),
    ],
  ),
  'stationary_bike': _Decor(
    keepProp: (p) => !_isWheel(p),
    extraProps: (p) {
      final wheels = [
        for (final pr in p.props)
          if (_isWheel(pr)) pr,
      ]..sort((a, b) => a.a.dx.compareTo(b.a.dx));
      final front = wheels.isNotEmpty ? wheels.last.a : const Offset(0.5, 0.35);
      final rear = wheels.isNotEmpty
          ? wheels.first.a
          : const Offset(-0.5, 0.35);
      return [
        Prop.rect(Offset(rear.dx - 0.12, 0), Offset(front.dx + 0.12, 0.05)),
        Prop.circle(front, 0.17),
        Prop.rect(
          p.wrist + const Offset(0.0, 0.05),
          p.wrist + const Offset(0.16, 0.19),
        ),
      ];
    },
  ),
  'hiit_cycling': _Decor(
    keepProp: (p) => !_isWheel(p),
    extraProps: (p) {
      final wheels = [
        for (final pr in p.props)
          if (_isWheel(pr)) pr,
      ]..sort((a, b) => a.a.dx.compareTo(b.a.dx));
      final front = wheels.isNotEmpty ? wheels.last.a : const Offset(0.5, 0.35);
      final rear = wheels.isNotEmpty
          ? wheels.first.a
          : const Offset(-0.5, 0.35);
      return [
        Prop.rect(Offset(rear.dx - 0.12, 0), Offset(front.dx + 0.12, 0.05)),
        Prop.circle(front, 0.17),
        Prop.rect(
          p.wrist + const Offset(0.0, 0.05),
          p.wrist + const Offset(0.16, 0.19),
        ),
      ];
    },
    front: const [_speedLines],
  ),
};

// ====================================================================
// Exercises with no animation: single hand-built poses.
// ====================================================================

final Map<String, ThumbSpec Function()> _staticSpecs = {
  'arnold_press': _arnold,
  'hiit_circuit': _jumpingJack,
  'football': _kick,
  'basketball': _jumpShot,
  'swimming': _freestyle,
  'boxing': _jab,
  'world_greatest_stretch': _worldsGreatest,
  'foam_rolling_full_body': _foamRoll,
  'doorway_chest_stretch': _doorway,
};

MotionDef _def(String id, MotionView view, Pose pose) =>
    MotionDef(id: id, title: id, cue: '', view: view, pose: (_) => pose);

/// A figure seen from the front (shoulders and hips level).
Pose _front({
  double hipY = 0.92,
  required double shoulderY,
  double ankleHalf = 0.14,
  double? headY,
  required Offset wristR,
  required Offset wristL,
  Offset elbowPoleR = const Offset(0.4, -1),
  Offset? elbowAtR,
  Offset? ankleR,
  Offset? ankleL,
  List<Prop> props = const [],
}) {
  const hipHalf = 0.11, shoulderHalf = 0.20;
  final hR = Offset(hipHalf, hipY), hL = Offset(-hipHalf, hipY);
  final aR = ankleR ?? Offset(ankleHalf, kAnkleHeight);
  final aL = ankleL ?? Offset(-ankleHalf, kAnkleHeight);
  final kR = twoBone(hR, aR, kThigh, kShin, const Offset(1, 0)).mid;
  final kL = twoBone(hL, aL, kThigh, kShin, const Offset(-1, 0)).mid;
  final sR = Offset(shoulderHalf, shoulderY),
      sL = Offset(-shoulderHalf, shoulderY);
  final eR =
      elbowAtR ?? twoBone(sR, wristR, kUpperArm, kForeArm, elbowPoleR).mid;
  final eL = elbowAtR != null
      ? Offset(-elbowAtR.dx, elbowAtR.dy)
      : twoBone(
          sL,
          wristL,
          kUpperArm,
          kForeArm,
          Offset(-elbowPoleR.dx, elbowPoleR.dy),
        ).mid;
  return Pose(
    hip: hR,
    knee: kR,
    ankle: aR,
    heel: aR + const Offset(0, -0.08),
    toe: aR + const Offset(0.10, -0.08),
    shoulder: sR,
    elbow: eR,
    wrist: wristR,
    head: Offset(0, headY ?? shoulderY + 0.24),
    focus: wristR,
    farKnee: kL,
    farAnkle: aL,
    farHeel: aL + const Offset(0, -0.08),
    farToe: aL + const Offset(-0.10, -0.08),
    farElbow: eL,
    farWrist: wristL,
    farShoulder: sL,
    farHip: hL,
    props: props,
  );
}

List<Prop> _dumbbellAt(Offset w) => [
  Prop.line(w + const Offset(-0.07, 0), w + const Offset(0.07, 0)),
  Prop.circle(w + const Offset(-0.07, 0), 0.05),
  Prop.circle(w + const Offset(0.07, 0), 0.05),
];

ThumbSpec _arnold() {
  // Mid-rotation: elbows out in front-to-side, forearms up, dumbbells at
  // shoulder height with rotation arrows around them.
  const sy = 1.44;
  const elbow = Offset(0.40, sy - 0.22);
  final wR = elbow + const Offset(-0.05, 0.265);
  final wL = Offset(-wR.dx, wR.dy);
  final pose = _front(
    shoulderY: sy,
    wristR: wR,
    wristL: wL,
    elbowAtR: elbow,
    props: [..._dumbbellAt(wR), ..._dumbbellAt(wL)],
  );
  void arrows(Canvas c, Offset Function(Offset) p, double s) {
    for (final w in [wR, wL]) {
      final ctr = p(w + Offset(w.dx > 0 ? 0.0 : 0.0, 0.0));
      final r = 0.15 * s;
      final side = w.dx > 0 ? 1.0 : -1.0;
      final rect = Rect.fromCircle(center: ctr, radius: r);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = FigurePainter.emerald;
      final start = side > 0 ? -2.6 : -0.54;
      final sweep = side > 0 ? 2.0 : -2.0;
      c.drawArc(rect, start, sweep, false, paint);
      final end = start + sweep;
      final tip = ctr + Offset(math.cos(end), math.sin(end)) * r;
      final dir = Offset(-math.sin(end), math.cos(end)) * (sweep > 0 ? 1 : -1);
      final n = Offset(-dir.dy, dir.dx);
      c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - dir * 11 + n * 6).dx, (tip - dir * 11 + n * 6).dy)
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - dir * 11 - n * 6).dx, (tip - dir * 11 - n * 6).dy),
        paint,
      );
    }
  }

  return ThumbSpec(
    _def('arnold_press', MotionView.front, pose),
    pose,
    front: [arrows],
  );
}

ThumbSpec _jumpingJack() {
  const sy = 1.38;
  final pose = _front(
    hipY: 0.86,
    shoulderY: sy,
    ankleR: const Offset(0.42, 0.10),
    ankleL: const Offset(-0.42, 0.10),
    wristR: const Offset(0.30, sy + 0.52),
    wristL: const Offset(-0.30, sy + 0.52),
    elbowPoleR: const Offset(1, 0.2),
  );
  return ThumbSpec(_def('hiit_circuit', MotionView.front, pose), pose);
}

void _ball(
  Canvas c,
  Offset Function(Offset) p,
  double s,
  Offset center,
  double r,
) {
  final pc = p(center);
  final pr = r * s;
  c.drawCircle(pc, pr, Paint()..color = const Color(0xFFE8EDF0));
  final seam = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF2B3238)
    ..strokeWidth = math.max(1.6, pr * 0.07);
  c.drawCircle(pc, pr, seam);
  c.drawCircle(pc, pr * 0.34, Paint()..color = const Color(0xFF2B3238));
  for (var i = 0; i < 5; i++) {
    final a = i * 2 * math.pi / 5 - math.pi / 2;
    c.drawLine(
      pc + Offset(math.cos(a), math.sin(a)) * pr * 0.34,
      pc + Offset(math.cos(a), math.sin(a)) * pr,
      seam,
    );
  }
}

ThumbSpec _kick() {
  final pose = person(
    hip: const Offset(0, 0.93),
    trunkAngle: -0.12,
    ankle: const Offset(-0.06, kAnkleHeight),
    wrist: const Offset(0.34, 1.02),
    elbowPole: const Offset(0.3, -1),
    kneePole: const Offset(1, 0.1),
    farAnkle: const Offset(0.60, 0.26),
    farKneePole: const Offset(0.3, 1),
    farWrist: const Offset(-0.36, 1.10),
    farElbowPole: const Offset(-0.3, -1),
  );
  return ThumbSpec(
    _def('football', MotionView.side, pose),
    pose,
    front: [(c, p, s) => _ball(c, p, s, const Offset(0.80, 0.14), 0.12)],
    fitPoints: const [Offset(0.94, 0.0), Offset(0.66, 0.26)],
  );
}

ThumbSpec _jumpShot() {
  final pose = person(
    hip: const Offset(0, 1.12),
    trunkAngle: 0.04,
    ankle: const Offset(-0.05, 0.30),
    heel: const Offset(-0.11, 0.24),
    toe: const Offset(0.08, 0.22),
    wrist: const Offset(0.26, 1.88),
    elbowPole: const Offset(0.2, -1),
    kneePole: const Offset(1, 0.2),
    farAnkle: const Offset(0.06, 0.26),
    farWrist: const Offset(0.16, 1.74),
    farElbowPole: const Offset(0.4, -1),
  );
  return ThumbSpec(
    _def('basketball', MotionView.side, pose),
    pose,
    front: [(c, p, s) => _ball(c, p, s, const Offset(0.30, 2.00), 0.12)],
    fitPoints: const [Offset(0.42, 2.14), Offset(0.18, 1.86)],
  );
}

ThumbSpec _freestyle() {
  final pose = person(
    hip: const Offset(-0.05, 0.20),
    shoulderAt: const Offset(0.47, 0.22),
    ankle: const Offset(-0.88, 0.14),
    wrist: const Offset(1.00, 0.24),
    elbowPole: const Offset(0, 1),
    kneePole: const Offset(0.2, 1),
    farAnkle: const Offset(-0.84, 0.34),
    farKneePole: const Offset(0.2, 1),
    farWrist: const Offset(0.38, -0.26),
    farElbowPole: const Offset(-0.5, -1),
    heel: const Offset(-0.94, 0.12),
    toe: const Offset(-0.80, 0.10),
    farHeel: const Offset(-0.90, 0.32),
    farToe: const Offset(-0.76, 0.30),
  );
  void water(Canvas c, Offset Function(Offset) p, double s) {
    final y = p(const Offset(0, 0.30)).dy;
    final rect = Rect.fromLTRB(0, y, 360, 360);
    c.drawRect(
      rect,
      Paint()..color = FigurePainter.emerald.withValues(alpha: 0.22),
    );
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= 360; x += 6) {
      path.lineTo(x, y + math.sin(x / 18) * 3);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = FigurePainter.emerald.withValues(alpha: 0.7),
    );
  }

  return ThumbSpec(
    _def('swimming', MotionView.side, pose),
    pose,
    front: [water],
    floor: false,
  );
}

ThumbSpec _jab() {
  final pose = person(
    hip: const Offset(-0.02, 0.88),
    trunkAngle: 0.10,
    ankle: const Offset(0.26, kAnkleHeight),
    wrist: const Offset(0.66, 1.40),
    elbowPole: const Offset(0, -1),
    kneePole: const Offset(1, 0.2),
    farAnkle: const Offset(-0.34, kAnkleHeight),
    farKneePole: const Offset(1, 0.2),
    farWrist: const Offset(0.20, 1.42),
    farElbowPole: const Offset(0, -1),
    props: [
      Prop.rect(const Offset(0.98, 0.42), const Offset(1.30, 1.75)),
      Prop.line(const Offset(1.14, 1.75), const Offset(1.14, 2.05)),
    ],
  );
  void glove(Canvas c, Offset Function(Offset) p, double s) {
    for (final (o, r) in [
      (const Offset(0.72, 1.40), 0.105),
      (const Offset(0.25, 1.44), 0.10),
    ]) {
      c.drawCircle(p(o), r * s, Paint()..color = const Color(0xFF2B3238));
      c.drawCircle(
        p(o),
        r * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = FigurePainter.emerald,
      );
    }
  }

  return ThumbSpec(_def('boxing', MotionView.side, pose), pose, front: [glove]);
}

ThumbSpec _worldsGreatest() {
  final pose = person(
    hip: const Offset(0.0, 0.46),
    trunkAngle: 1.30,
    ankle: const Offset(0.66, kAnkleHeight),
    wrist: const Offset(0.42, 0.04),
    elbowPole: const Offset(0.6, -0.4),
    kneePole: const Offset(1, 0.5),
    farAnkle: const Offset(-0.72, 0.10),
    farKneePole: const Offset(0.2, 1),
    farWrist: const Offset(0.62, 1.12),
    farElbowPole: const Offset(0.4, 0.3),
    farHeel: const Offset(-0.80, 0.06),
    farToe: const Offset(-0.62, 0.06),
  );
  return ThumbSpec(_def('world_greatest_stretch', MotionView.side, pose), pose);
}

ThumbSpec _foamRoll() {
  const roller = Offset(0.30, 0.14);
  final pose = person(
    hip: const Offset(-0.22, 0.26),
    shoulderAt: const Offset(0.30, 0.38),
    ankle: const Offset(-0.62, 0.09),
    wrist: const Offset(0.20, 0.55),
    elbowPole: const Offset(0.2, 1),
    kneePole: const Offset(0.2, 1),
    elbowAt: const Offset(0.42, 0.58),
    props: [Prop.circle(roller, 0.14)],
  );
  return ThumbSpec(_def('foam_rolling_full_body', MotionView.side, pose), pose);
}

ThumbSpec _doorway() {
  const sy = 1.44;
  final wR = const Offset(0.50, sy + 0.27), wL = const Offset(-0.50, sy + 0.27);
  final pose = _front(
    shoulderY: sy,
    wristR: wR,
    wristL: wL,
    elbowPoleR: const Offset(1, -0.1),
    props: [
      Prop.rect(const Offset(0.54, 0), const Offset(0.66, 2.15)),
      Prop.rect(const Offset(-0.66, 0), const Offset(-0.54, 2.15)),
      Prop.rect(const Offset(-0.66, 2.05), const Offset(0.66, 2.15)),
    ],
  );
  return ThumbSpec(_def('doorway_chest_stretch', MotionView.front, pose), pose);
}
