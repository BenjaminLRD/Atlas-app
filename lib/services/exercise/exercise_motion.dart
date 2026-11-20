import 'dart:math' as math;
import 'dart:ui';

part 'exercise_motion_extra.dart';
part 'exercise_motion_views.dart';

/// Form demonstrations drawn from joint geometry.
///
/// Each demonstration is a side-view figure with real limb lengths. Feet and
/// hands that must stay planted or on a bar are held at fixed points and the
/// knees and elbows are solved from them (two-bone inverse kinematics), so
/// limb lengths never change and the figure cannot take an impossible pose.
/// Tests check this for every demonstration at many points of the movement.

// Segment lengths in metres, for a 1.75 m adult.
const double kThigh = 0.43;
const double kShin = 0.43;
const double kUpperArm = 0.30;
const double kForeArm = 0.27;
const double kTrunk = 0.52;
const double kAnkleHeight = 0.08;
const double kHeel = 0.07;
const double kToe = 0.19;
const double kHeadOffset = 0.24;

/// Reaches a target a hair short of fully straight so the solution is defined.
const double kStraight = 0.9985;

enum MotionPhase { eccentric, concentric, hold, cycle }

enum PropKind { line, circle, rect }

class Prop {
  final PropKind kind;
  final Offset a;
  final Offset b;
  final double radius;
  final bool filled;
  final bool dashed;
  const Prop.line(this.a, this.b, {this.dashed = false})
    : kind = PropKind.line,
      radius = 0,
      filled = false;
  const Prop.circle(this.a, this.radius, {this.filled = true})
    : kind = PropKind.circle,
      b = Offset.zero,
      dashed = false;
  const Prop.rect(this.a, this.b, {this.filled = true})
    : kind = PropKind.rect,
      radius = 0,
      dashed = false;

  Prop translated(Offset d) => switch (kind) {
    PropKind.line => Prop.line(a + d, b + d, dashed: dashed),
    PropKind.circle => Prop.circle(a + d, radius, filled: filled),
    PropKind.rect => Prop.rect(a + d, b + d, filled: filled),
  };
}

/// Which way the figure is drawn.
enum MotionView { side, front, top }

/// One frame of a demonstration. y is up, x is the direction the figure faces.
class Pose {
  final Offset hip;
  final Offset knee;
  final Offset ankle;
  final Offset heel;
  final Offset toe;
  final Offset shoulder;
  final Offset elbow;
  final Offset wrist;
  final Offset head;

  /// The far leg and arm, drawn dimmer behind the near ones.
  final Offset? farKnee;
  final Offset? farAnkle;
  final Offset? farHeel;
  final Offset? farToe;
  final Offset? farElbow;
  final Offset? farWrist;

  /// A curved spine, when the demonstration is about the spine.
  final List<Offset>? spine;

  final List<Prop> props;

  /// The point whose motion the arrow follows (usually the hand or the hip).
  final Offset focus;

  /// Distance by which any held point could not be reached (0 when every limb
  /// reaches exactly where the demonstration says it should).
  final double reachError;

  /// Front and top views only: the other shoulder and hip.
  final Offset? farShoulder;
  final Offset? farHip;

  /// Distance the body has travelled along the ground since the start of the
  /// cycle. Used to scroll the ground marks so a walking or running figure
  /// can stay in the middle of the picture.
  final double travel;

  const Pose({
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.heel,
    required this.toe,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.head,
    required this.focus,
    this.farKnee,
    this.farAnkle,
    this.farHeel,
    this.farToe,
    this.farElbow,
    this.farWrist,
    this.spine,
    this.props = const [],
    this.reachError = 0,
    this.farShoulder,
    this.farHip,
    this.travel = 0,
  });

  /// The same pose moved by [d].
  Pose translated(Offset d, {double? travel}) {
    Offset? mv(Offset? o) => o == null ? null : o + d;
    return Pose(
      hip: hip + d,
      knee: knee + d,
      ankle: ankle + d,
      heel: heel + d,
      toe: toe + d,
      shoulder: shoulder + d,
      elbow: elbow + d,
      wrist: wrist + d,
      head: head + d,
      focus: focus + d,
      farKnee: mv(farKnee),
      farAnkle: mv(farAnkle),
      farHeel: mv(farHeel),
      farToe: mv(farToe),
      farElbow: mv(farElbow),
      farWrist: mv(farWrist),
      spine: spine?.map((o) => o + d).toList(),
      props: [for (final p in props) p.translated(d)],
      reachError: reachError,
      farShoulder: mv(farShoulder),
      farHip: mv(farHip),
      travel: travel ?? this.travel,
    );
  }

  /// The same pose with the given props.
  Pose withProps(List<Prop> props) => Pose(
    hip: hip,
    knee: knee,
    ankle: ankle,
    heel: heel,
    toe: toe,
    shoulder: shoulder,
    elbow: elbow,
    wrist: wrist,
    head: head,
    focus: focus,
    farKnee: farKnee,
    farAnkle: farAnkle,
    farHeel: farHeel,
    farToe: farToe,
    farElbow: farElbow,
    farWrist: farWrist,
    spine: spine,
    props: props,
    reachError: reachError,
    farShoulder: farShoulder,
    farHip: farHip,
    travel: travel,
  );
}

Offset polar(double len, double angleFromVertical) => Offset(
  len * math.sin(angleFromVertical),
  len * math.cos(angleFromVertical),
);

/// A limb hanging down from a joint: [angle] is measured from straight down,
/// positive toward the direction the figure faces.
Offset down(double len, double angle) =>
    Offset(len * math.sin(angle), -len * math.cos(angle));

/// Solved two-bone chain: the middle joint and how far the end was out of
/// reach.
class Chain {
  final Offset mid;
  final double error;
  const Chain(this.mid, this.error);
}

Chain twoBone(Offset root, Offset target, double l1, double l2, Offset pole) {
  final delta = target - root;
  var d = delta.distance;
  var err = 0.0;
  final reach = (l1 + l2) * kStraight;
  if (d > reach) {
    err = d - reach;
    d = reach;
  }
  final minReach = (l1 - l2).abs() + 1e-3;
  if (d < minReach) {
    err = minReach - d;
    d = minReach;
  }
  final dir = d == 0 || delta.distance == 0
      ? const Offset(0, -1)
      : delta / delta.distance;
  final a = (l1 * l1 - l2 * l2 + d * d) / (2 * d);
  final h = math.sqrt(math.max(0, l1 * l1 - a * a));
  final perp = Offset(-dir.dy, dir.dx);
  final p1 = root + dir * a + perp * h;
  final p2 = root + dir * a - perp * h;
  final dot1 = (p1 - root).dx * pole.dx + (p1 - root).dy * pole.dy;
  final dot2 = (p2 - root).dx * pole.dx + (p2 - root).dy * pole.dy;
  return Chain(dot1 >= dot2 ? p1 : p2, err);
}

Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;
double _lerpD(double a, double b, double t) => a + (b - a) * t;
double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

/// Smooth 0..1 easing.
double ease(double x) {
  final t = _clamp01(x);
  return t * t * (3 - 2 * t);
}

Offset _flatHeel(Offset ankle) =>
    Offset(ankle.dx - kHeel, ankle.dy - kAnkleHeight);
Offset _flatToe(Offset ankle) =>
    Offset(ankle.dx + kToe, ankle.dy - kAnkleHeight);

/// Builds a figure. Legs are solved from the hip to [ankle]; arms from the
/// shoulder to [wrist], unless a joint is given directly.
Pose person({
  required Offset hip,
  double? trunkAngle,
  Offset? shoulderAt,
  required Offset ankle,
  required Offset wrist,
  Offset kneePole = const Offset(1, 0.3),
  Offset elbowPole = const Offset(0, -1),
  Offset? kneeAt,
  Offset? elbowAt,
  Offset? heel,
  Offset? toe,
  Offset? farAnkle,
  Offset farKneePole = const Offset(1, 0.3),
  Offset? farHeel,
  Offset? farToe,
  Offset? farWrist,
  Offset? farElbowAt,
  Offset farElbowPole = const Offset(0, -1),
  Offset? focus,
  List<Offset>? spine,
  List<Prop> props = const [],
  double headTilt = 0,
}) {
  final shoulder = shoulderAt ?? hip + polar(kTrunk, trunkAngle ?? 0);
  final trunkDir = shoulder - hip;
  final angle = math.atan2(trunkDir.dx, trunkDir.dy);
  final head = shoulder + polar(kHeadOffset, angle + headTilt);
  var err = 0.0;
  Offset knee;
  if (kneeAt != null) {
    knee = kneeAt;
  } else {
    final c = twoBone(hip, ankle, kThigh, kShin, kneePole);
    knee = c.mid;
    err += c.error;
  }
  Offset elbow;
  if (elbowAt != null) {
    elbow = elbowAt;
  } else {
    final c = twoBone(shoulder, wrist, kUpperArm, kForeArm, elbowPole);
    elbow = c.mid;
    err += c.error;
  }
  Offset? farKnee;
  if (farAnkle != null) {
    final c = twoBone(hip, farAnkle, kThigh, kShin, farKneePole);
    farKnee = c.mid;
    err += c.error;
  }
  Offset? farElbow;
  if (farElbowAt != null) {
    farElbow = farElbowAt;
  } else if (farWrist != null) {
    final c = twoBone(shoulder, farWrist, kUpperArm, kForeArm, farElbowPole);
    farElbow = c.mid;
    err += c.error;
  }
  return Pose(
    hip: hip,
    knee: knee,
    ankle: ankle,
    heel: heel ?? _flatHeel(ankle),
    toe: toe ?? _flatToe(ankle),
    shoulder: shoulder,
    elbow: elbow,
    wrist: wrist,
    head: head,
    focus: focus ?? wrist,
    farKnee: farKnee,
    farAnkle: farAnkle,
    farHeel: farAnkle == null ? null : (farHeel ?? _flatHeel(farAnkle)),
    farToe: farAnkle == null ? null : (farToe ?? _flatToe(farAnkle)),
    farElbow: farElbow,
    farWrist: farWrist,
    spine: spine,
    props: props,
    reachError: err,
  );
}

/// One demonstration.
class MotionDef {
  final String id;
  final String title;

  /// Where the movement starts and what it does, in a sentence.
  final String cue;

  /// Which half of the repetition comes first.
  final MotionPhase firstHalf;

  /// Held position (plank): the figure breathes instead of moving.
  final bool isometric;

  /// Repeating cycle (running, cycling): no lowering and lifting halves.
  final bool cyclic;

  final double cycleSeconds;

  /// A limitation worth showing, for example "shown as a stationary lunge".
  final String? note;

  /// Which way the figure is drawn, and the text shown for it.
  final MotionView view;
  final String viewLabel;

  /// Cyclic motions that travel (walking, running): how far the body moves in
  /// one cycle, so the ground marks can scroll without a jump at the loop.
  final double? travelPerCycle;

  /// Set when this view is an orthographic projection of the side-view
  /// demonstration with this id (heights shared, sideways positions added).
  final String? projectedFrom;

  /// `d` goes from 0 (start position) to 1 (end of the first half).
  final Pose Function(double d) pose;

  const MotionDef({
    required this.id,
    required this.title,
    required this.cue,
    required this.pose,
    this.firstHalf = MotionPhase.eccentric,
    this.isometric = false,
    this.cyclic = false,
    this.cycleSeconds = 3.2,
    this.note,
    this.view = MotionView.side,
    this.viewLabel = 'Side view',
    this.travelPerCycle,
    this.projectedFrom,
  });

  /// Progress `d` and phase for a point `t` (0..1) of one repetition.
  ({double d, MotionPhase phase}) at(double t) {
    final x = t - t.floorToDouble();
    if (cyclic) return (d: x, phase: MotionPhase.cycle);
    if (isometric) {
      return (
        d: 0.5 + 0.5 * math.sin(x * 2 * math.pi),
        phase: MotionPhase.hold,
      );
    }
    final second = firstHalf == MotionPhase.eccentric
        ? MotionPhase.concentric
        : MotionPhase.eccentric;
    if (x < 0.44) return (d: ease(x / 0.44), phase: firstHalf);
    if (x < 0.56) return (d: 1, phase: MotionPhase.hold);
    if (x < 0.96) return (d: 1 - ease((x - 0.56) / 0.40), phase: second);
    return (d: 0, phase: MotionPhase.hold);
  }

  Pose poseAt(double t) => pose(at(t).d);
}

// ------------------------------------------------------------ templates

const _floorAnkle = Offset(0, kAnkleHeight);

List<Prop> _plate(Offset c, {double r = 0.225}) => [Prop.circle(c, r)];

Pose _squatPose(
  double d, {
  required double shoulderX,
  double hipBack = -0.36,
  required Offset Function(Offset shoulder) wristFor,
  Offset elbowPole = const Offset(0, -1),
  List<Prop> Function(Offset wrist)? props,
}) {
  final hip = Offset(_lerpD(-0.02, hipBack, d), _lerpD(0.92, 0.40, d));
  final s = ((shoulderX - hip.dx) / kTrunk).clamp(-1.0, 1.0);
  final theta = math.asin(s);
  final shoulder = hip + polar(kTrunk, theta);
  final wrist = wristFor(shoulder);
  return person(
    hip: hip,
    trunkAngle: theta,
    ankle: _floorAnkle,
    wrist: wrist,
    elbowPole: elbowPole,
    props: props?.call(wrist) ?? const [],
  );
}

MotionDef _squat(String id, String title) => MotionDef(
  id: id,
  title: title,
  cue:
      'Bar on your upper back over mid-foot. Sit hips back and down until the '
      'thighs pass parallel, knees tracking over the toes, then drive up.',
  pose: (d) => _squatPose(
    d,
    shoulderX: 0.02,
    wristFor: (s) => s + const Offset(-0.05, 0.01),
    elbowPole: const Offset(-0.3, -1),
    props: (w) => _plate(w),
  ),
);

MotionDef _airSquat(String id, String title) => MotionDef(
  id: id,
  title: title,
  cue:
      'Feet shoulder-width. Reach the arms forward for balance, sit hips back '
      'and down until the thighs pass parallel, then stand tall.',
  pose: (d) => _squatPose(
    d,
    shoulderX: 0.12,
    hipBack: -0.30,
    wristFor: (s) => s + const Offset(0.50, 0.0),
    elbowPole: const Offset(0, -1),
  ),
);

MotionDef _gobletSquat(String id, String title) => MotionDef(
  id: id,
  title: title,
  cue:
      'Hold the weight at your chest with elbows down. Sit between the hips, '
      'chest tall, then stand.',
  pose: (d) => _squatPose(
    d,
    shoulderX: 0.10,
    hipBack: -0.28,
    wristFor: (s) => s + const Offset(0.15, -0.20),
    elbowPole: const Offset(0.3, -1),
    props: (w) => [Prop.circle(w + const Offset(0.02, 0.0), 0.07)],
  ),
);

/// Two circles' intersection: the point at [r1] from [c1] and [r2] from [c2],
/// choosing the one with the smaller x.
Offset _circleHip(Offset c1, double r1, Offset c2, double r2) {
  final d = (c2 - c1).distance;
  final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  final h = math.sqrt(math.max(0, r1 * r1 - a * a));
  final dir = (c2 - c1) / d;
  final perp = Offset(-dir.dy, dir.dx);
  final p1 = c1 + dir * a + perp * h;
  final p2 = c1 + dir * a - perp * h;
  return p1.dx < p2.dx ? p1 : p2;
}

MotionDef _deadlift(String id, String title) => MotionDef(
  id: id,
  title: title,
  firstHalf: MotionPhase.concentric,
  cue:
      'Bar over mid-foot, arms straight, back flat. Push the floor away so '
      'the hips and shoulders rise together, stand tall, then lower the bar '
      'back along the legs.',
  pose: (d) {
    final barY = _lerpD(0.225, 0.87, d);
    final shoulder = Offset(0.02, barY + kUpperArm + kForeArm - 0.01);
    final reach = _lerpD(0.69, 0.852, d);
    final hip = _circleHip(shoulder, kTrunk, _floorAnkle, reach);
    final wrist = Offset(0.02, barY);
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: _floorAnkle,
      wrist: wrist,
      elbowPole: const Offset(0, 1),
      props: _plate(wrist),
    );
  },
);

MotionDef _rdl(String id, String title, {required bool barbell}) => MotionDef(
  id: id,
  title: title,
  cue:
      'Soft knees that stay put. Push the hips straight back so the weight '
      'slides down the thighs with a flat back, until the hamstrings stretch, '
      'then drive the hips forward.',
  pose: (d) {
    final knee = _floorAnkle + polar(kShin, 0.18);
    final phi = _lerpD(0.25, 0.75, d);
    final hip = knee + Offset(-kThigh * math.sin(phi), kThigh * math.cos(phi));
    final theta = _lerpD(0.10, 1.25, d);
    final shoulder = hip + polar(kTrunk, theta);
    final wrist = Offset(
      shoulder.dx,
      shoulder.dy - (kUpperArm + kForeArm) * 0.995,
    );
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: _floorAnkle,
      kneeAt: knee,
      wrist: wrist,
      props: barbell
          ? _plate(wrist)
          : [Prop.circle(wrist + const Offset(0, -0.04), 0.07)],
    );
  },
);

// Lying figures face right with the head at the left.
List<Prop> _flatBench() => const [
  Prop.rect(Offset(-0.85, 0.36), Offset(0.22, 0.45)),
  Prop.line(Offset(-0.70, 0.36), Offset(-0.70, 0.0)),
  Prop.line(Offset(0.08, 0.36), Offset(0.08, 0.0)),
];

MotionDef _benchPress(
  String id,
  String title, {
  required bool dumbbells,
}) => MotionDef(
  id: id,
  title: title,
  cue:
      'Shoulder blades pinched, feet planted. Lower under control to the '
      'middle of the chest with elbows about 45 degrees from the body, then '
      'press back up over the shoulders.',
  pose: (d) {
    const hip = Offset(0.0, 0.58);
    const theta = -math.pi / 2 + 0.06;
    final shoulder = hip + polar(kTrunk, theta);
    final top = Offset(shoulder.dx + 0.04, shoulder.dy + 0.55);
    final bottom = Offset(shoulder.dx + 0.10, shoulder.dy + 0.12);
    final wrist = _lerp(top, bottom, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.42, kAnkleHeight),
      wrist: wrist,
      kneePole: const Offset(0, 1),
      elbowPole: const Offset(0.6, -1),
      props: [
        ..._flatBench(),
        if (dumbbells) Prop.circle(wrist, 0.07) else Prop.circle(wrist, 0.225),
      ],
    );
  },
);

MotionDef _inclinePress(
  String id,
  String title, {
  required bool dumbbells,
}) => MotionDef(
  id: id,
  title: title,
  cue:
      'Bench at about 30 degrees, shoulder blades pinched. Lower to the upper '
      'chest, elbows about 45 degrees from the body, then press straight up.',
  pose: (d) {
    const incline = 0.55; // bench angle above horizontal
    const hip = Offset(0.0, 0.55);
    final theta = -(math.pi / 2 - incline);
    final shoulder = hip + polar(kTrunk, theta);
    final u = (shoulder - hip) / kTrunk;
    final n = Offset(u.dy, -u.dx);
    final top = Offset(shoulder.dx + 0.06, shoulder.dy + 0.55);
    final bottom = shoulder - u * 0.08 + n * 0.12;
    final wrist = _lerp(top, bottom, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.40, kAnkleHeight),
      wrist: wrist,
      kneePole: const Offset(0.2, 1),
      elbowPole: const Offset(0.6, -1),
      props: [
        Prop.line(
          hip + const Offset(0.05, -0.12),
          shoulder + u * 0.20 + const Offset(0, -0.12),
        ),
        Prop.line(const Offset(0.05, 0.43), const Offset(0.05, 0.0)),
        Prop.line(
          shoulder + u * 0.20 + const Offset(0, -0.12),
          shoulder + u * 0.20 + const Offset(-0.05, -0.55),
        ),
        if (dumbbells) Prop.circle(wrist, 0.07) else Prop.circle(wrist, 0.225),
      ],
    );
  },
);

MotionDef _pushUp() => MotionDef(
  id: 'push_ups',
  title: 'Push-ups',
  cue:
      'Hands under the shoulders, body in one straight line from head to heels. '
      'Lower the chest toward the floor with elbows about 45 degrees back, '
      'then push the floor away.',
  pose: (d) {
    const ankle = Offset(-0.95, 0.17);
    const handX = 0.366;
    final shoulderY = _lerpD(0.57, 0.20, d);
    final alpha = math.asin(((shoulderY - ankle.dy) / 1.38).clamp(-1.0, 1.0));
    final shoulder =
        ankle + Offset(1.38 * math.cos(alpha), 1.38 * math.sin(alpha));
    final hip = ankle + Offset(0.86 * math.cos(alpha), 0.86 * math.sin(alpha));
    final knee = ankle + Offset(0.43 * math.cos(alpha), 0.43 * math.sin(alpha));
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: ankle,
      kneeAt: knee,
      heel: const Offset(-0.99, 0.12),
      toe: const Offset(-0.90, 0.0),
      wrist: const Offset(handX, 0.04),
      elbowPole: const Offset(-1, 0.4),
      props: const [],
    );
  },
);

MotionDef _overheadPress(String id, String title, {required bool seated}) =>
    MotionDef(
      id: id,
      title: title,
      firstHalf: MotionPhase.concentric,
      cue:
          'Hold the weight at shoulder height, ribs down and core tight. Press '
          'straight overhead until the arms lock out, then lower back to the '
          'shoulders.',
      pose: (d) {
        final hip = seated
            ? const Offset(-0.05, 0.50)
            : const Offset(0.0, 0.92);
        final theta = seated ? -0.08 : 0.02;
        final shoulder = hip + polar(kTrunk, theta);
        final start = shoulder + const Offset(0.07, 0.03);
        final end = shoulder + const Offset(0.02, 0.555);
        final wrist = _lerp(start, end, d);
        return person(
          hip: hip,
          trunkAngle: theta,
          ankle: seated ? const Offset(0.42, kAnkleHeight) : _floorAnkle,
          wrist: wrist,
          kneePole: const Offset(0.4, 1),
          elbowPole: const Offset(0.4, -1),
          props: [
            if (seated) ...[
              const Prop.rect(Offset(-0.35, 0.40), Offset(0.15, 0.46)),
              const Prop.line(Offset(-0.34, 0.46), Offset(-0.40, 1.15)),
            ],
            Prop.circle(wrist, seated ? 0.07 : 0.225),
          ],
        );
      },
    );

/// Standing curl: the elbow stays fixed beside the body; the forearm rotates.
MotionDef _curl(String id, String title, {String? grip, bool cable = false}) =>
    MotionDef(
      id: id,
      title: title,
      firstHalf: MotionPhase.concentric,
      cue:
          'Elbows pinned to your sides, standing tall. Curl the weight up by '
          'bending only the elbow${grip == null ? '' : ' ($grip)'}, squeeze at '
          'the top, then lower slowly.',
      pose: (d) {
        const hip = Offset(0.0, 0.92);
        final shoulder = hip + polar(kTrunk, 0.0);
        final elbow = shoulder + const Offset(0.02, -kUpperArm);
        final psi = _lerpD(0.05, 2.45, d);
        final wrist =
            elbow + Offset(kForeArm * math.sin(psi), -kForeArm * math.cos(psi));
        return person(
          hip: hip,
          trunkAngle: 0.0,
          ankle: _floorAnkle,
          wrist: wrist,
          elbowAt: elbow,
          props: [
            if (cable) Prop.line(wrist, const Offset(0.85, 0.08), dashed: true),
            Prop.circle(wrist, cable ? 0.04 : 0.07),
          ],
        );
      },
    );

MotionDef _bentRow() => MotionDef(
  id: 'barbell_row',
  title: 'Barbell Bent-Over Row',
  firstHalf: MotionPhase.concentric,
  cue:
      'Hinge until the back is about 25 degrees above horizontal, flat and '
      'braced. Row the bar to the lower ribs, elbows back, then lower under '
      'control.',
  pose: (d) {
    const hip = Offset(-0.20, 0.80);
    const theta = 1.15;
    final shoulder = hip + polar(kTrunk, theta);
    final hang = Offset(
      shoulder.dx,
      shoulder.dy - (kUpperArm + kForeArm) * 0.995,
    );
    const pulled = Offset(0.10, 0.76);
    final wrist = _lerp(hang, pulled, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: _floorAnkle,
      kneeAt: _floorAnkle + polar(kShin, 0.18),
      wrist: wrist,
      elbowPole: const Offset(-1, 0.4),
      props: _plate(wrist, r: 0.14),
    );
  },
);

MotionDef _seatedRow() => MotionDef(
  id: 'seated_cable_row',
  title: 'Seated Cable Row',
  firstHalf: MotionPhase.concentric,
  cue:
      'Sit tall with a slight knee bend. Pull the handle to your lower ribs, '
      'drawing the shoulder blades together, then let the arms reach forward '
      'under control.',
  pose: (d) {
    const hip = Offset(-0.45, 0.30);
    final theta = _lerpD(0.12, -0.10, d);
    final shoulder = hip + polar(kTrunk, theta);
    final start = shoulder + const Offset(0.55, -0.12);
    final end = hip + const Offset(0.14, 0.30);
    final wrist = _lerp(start, end, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.35, 0.18),
      wrist: wrist,
      kneePole: const Offset(0, 1),
      elbowPole: const Offset(-0.2, -1),
      props: [
        const Prop.rect(Offset(-0.60, 0.20), Offset(-0.25, 0.28)),
        Prop.line(wrist, const Offset(1.05, 0.52), dashed: true),
        const Prop.rect(Offset(0.28, 0.0), Offset(0.40, 0.30)),
      ],
    );
  },
);

MotionDef _pullUp(String id, String title, String grip) => MotionDef(
  id: id,
  title: title,
  firstHalf: MotionPhase.concentric,
  cue:
      'Start from a dead hang ($grip). Pull the elbows down and back until the '
      'chin clears the bar, then lower fully under control.',
  pose: (d) {
    const barY = 2.20;
    const wrist = Offset(0.08, barY);
    final shoulderY = _lerpD(barY - 0.565, barY - 0.20, d);
    final theta = _lerpD(0.0, -0.18, d);
    final shoulder = Offset(0.0, shoulderY);
    final hip = shoulder - polar(kTrunk, theta);
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: hip + const Offset(-0.50, -0.33),
      wrist: wrist,
      kneePole: const Offset(0.4, -1),
      elbowPole: const Offset(-0.6, -1),
      heel: hip + const Offset(-0.58, -0.40),
      toe: hip + const Offset(-0.34, -0.38),
      props: const [
        Prop.line(Offset(-0.5, barY), Offset(0.5, barY)),
        Prop.line(Offset(-0.5, barY), Offset(-0.5, 0.0)),
      ],
    );
  },
);

MotionDef _latPulldown() => MotionDef(
  id: 'lat_pulldown',
  title: 'Wide-Grip Lat Pulldown',
  firstHalf: MotionPhase.concentric,
  cue:
      'Sit with the thighs under the pad. Pull the bar to the upper chest, '
      'leading with the elbows, leaning back only slightly, then let it rise '
      'under control.',
  pose: (d) {
    const hip = Offset(-0.20, 0.50);
    final theta = _lerpD(0.0, -0.20, d);
    final shoulder = hip + polar(kTrunk, theta);
    final start = shoulder + const Offset(0.10, 0.555);
    final end = shoulder + const Offset(0.18, -0.12);
    final wrist = _lerp(start, end, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.25, kAnkleHeight),
      wrist: wrist,
      kneePole: const Offset(0, 1),
      elbowPole: const Offset(-0.5, -1),
      props: [
        const Prop.rect(Offset(-0.40, 0.40), Offset(0.05, 0.46)),
        const Prop.line(Offset(0.12, 0.70), Offset(0.12, 0.55)),
        Prop.line(wrist, const Offset(0.35, 2.15), dashed: true),
      ],
    );
  },
);

MotionDef _pushdown() => MotionDef(
  id: 'tricep_pushdown',
  title: 'Cable Tricep Pushdown',
  firstHalf: MotionPhase.concentric,
  cue:
      'Elbows pinned to your sides. Push the handle down by straightening only '
      'the elbows, squeeze the triceps at the bottom, then let it rise until '
      'the forearms are level.',
  pose: (d) {
    const hip = Offset(0.0, 0.92);
    final shoulder = hip + polar(kTrunk, 0.05);
    final elbow = shoulder + const Offset(0.02, -kUpperArm);
    final psi = _lerpD(math.pi / 2, 0.04, d);
    final wrist =
        elbow + Offset(kForeArm * math.sin(psi), -kForeArm * math.cos(psi));
    return person(
      hip: hip,
      trunkAngle: 0.05,
      ankle: _floorAnkle,
      wrist: wrist,
      elbowAt: elbow,
      props: [
        Prop.line(wrist, const Offset(0.40, 2.10), dashed: true),
        Prop.circle(wrist, 0.04),
      ],
    );
  },
);

MotionDef _skullCrusher() => MotionDef(
  id: 'skull_crushers',
  title: 'EZ-Bar Skull Crushers',
  cue:
      'Lie flat, bar over the shoulders with elbows pointing at the ceiling. '
      'Bend only the elbows to lower the bar toward the forehead, then '
      'straighten the arms again.',
  pose: (d) {
    const hip = Offset(0.0, 0.58);
    const theta = -math.pi / 2 + 0.06;
    final shoulder = hip + polar(kTrunk, theta);
    final elbow = shoulder + const Offset(0.0, kUpperArm);
    final psi = _lerpD(0.0, 1.85, d);
    final wrist =
        elbow + Offset(-kForeArm * math.sin(psi), kForeArm * math.cos(psi));
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.42, kAnkleHeight),
      wrist: wrist,
      elbowAt: elbow,
      kneePole: const Offset(0, 1),
      props: [..._flatBench(), Prop.circle(wrist, 0.10)],
    );
  },
);

MotionDef _legExtension() => MotionDef(
  id: 'leg_extension',
  title: 'Leg Extension Machine',
  firstHalf: MotionPhase.concentric,
  cue:
      'Sit back with the pad just above the ankles. Straighten the knees to '
      'lift the pad, squeeze the thighs at the top, then lower slowly without '
      'letting the stack touch down.',
  pose: (d) {
    const hip = Offset(-0.05, 0.50);
    const knee = Offset(0.38, 0.52);
    final beta = _lerpD(0.0, 1.42, d);
    final ankle =
        knee + Offset(kShin * math.sin(beta), -kShin * math.cos(beta));
    return person(
      hip: hip,
      trunkAngle: -0.10,
      ankle: ankle,
      kneeAt: knee,
      wrist: const Offset(0.20, 0.52),
      elbowPole: const Offset(0, -1),
      heel: ankle + const Offset(-0.03, -0.07),
      toe: ankle + const Offset(0.08, -0.05),
      props: [
        const Prop.rect(Offset(-0.30, 0.40), Offset(0.35, 0.47)),
        const Prop.line(Offset(-0.32, 0.47), Offset(-0.38, 1.15)),
        Prop.line(
          ankle + const Offset(0.02, -0.02),
          ankle + const Offset(0.02, 0.10),
        ),
      ],
    );
  },
);

MotionDef _calfRaise() => MotionDef(
  id: 'standing_calf_raise',
  title: 'Standing Calf Raise',
  firstHalf: MotionPhase.concentric,
  cue:
      'Stand tall on the balls of the feet. Rise as high as you can, pause at '
      'the top, then lower the heels below the step for a full stretch.',
  pose: (d) {
    final phi = _lerpD(0.0, 0.55, d);
    const ball = Offset(0.19, 0.0);
    final ankle =
        ball +
        Offset(
          -0.19 * math.cos(phi) + 0.08 * math.sin(phi),
          0.19 * math.sin(phi) + 0.08 * math.cos(phi),
        );
    final heel = ball + Offset(-0.26 * math.cos(phi), 0.26 * math.sin(phi));
    final hip = ankle + const Offset(0.0, 0.84);
    return person(
      hip: hip,
      trunkAngle: 0.0,
      ankle: ankle,
      heel: heel,
      toe: ball,
      wrist: hip + polar(kTrunk, 0) + const Offset(0.03, -0.55),
      props: const [Prop.rect(Offset(-0.30, -0.08), Offset(0.35, 0.0))],
    );
  },
);

MotionDef _plank() => MotionDef(
  id: 'plank',
  title: 'Forearm Plank Hold',
  isometric: true,
  firstHalf: MotionPhase.hold,
  cue:
      'Forearms under the shoulders, body in one straight line from head to '
      'heels. Brace the abs, squeeze the glutes and breathe. This is a hold, '
      'so the figure stays still.',
  pose: (d) {
    const ankle = Offset(-0.95, 0.17);
    final shoulderY = 0.34 + 0.006 * d;
    final alpha = math.asin(((shoulderY - ankle.dy) / 1.38).clamp(-1.0, 1.0));
    final shoulder =
        ankle + Offset(1.38 * math.cos(alpha), 1.38 * math.sin(alpha));
    final hip = ankle + Offset(0.86 * math.cos(alpha), 0.86 * math.sin(alpha));
    final knee = ankle + Offset(0.43 * math.cos(alpha), 0.43 * math.sin(alpha));
    final elbow = Offset(shoulder.dx, 0.04);
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: ankle,
      kneeAt: knee,
      heel: const Offset(-0.99, 0.12),
      toe: const Offset(-0.90, 0.0),
      wrist: elbow + const Offset(0.27, 0.0),
      elbowAt: elbow,
    );
  },
);

MotionDef _hangingLegRaise() => MotionDef(
  id: 'hanging_leg_raise',
  title: 'Hanging Leg Raise',
  firstHalf: MotionPhase.concentric,
  cue:
      'Hang from the bar with straight arms. Without swinging, raise the legs '
      'in front of you to about hip height, tilting the pelvis up, then lower '
      'slowly. Bend the knees to make it easier.',
  pose: (d) {
    const barY = 2.20;
    const wrist = Offset(0.08, barY);
    final shoulder = const Offset(0.0, barY - 0.565);
    final hip = shoulder - const Offset(0.0, kTrunk);
    final gamma = _lerpD(0.04, 1.45, d);
    final ankle =
        hip +
        Offset(
          kStraight * 0.86 * math.sin(gamma),
          -kStraight * 0.86 * math.cos(gamma),
        );
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: ankle,
      wrist: wrist,
      elbowPole: const Offset(-0.6, -1),
      heel: ankle + const Offset(-0.02, -0.07),
      toe: ankle + const Offset(0.12, -0.05),
      props: const [
        Prop.line(Offset(-0.5, barY), Offset(0.5, barY)),
        Prop.line(Offset(-0.5, barY), Offset(-0.5, 0.0)),
      ],
    );
  },
);

MotionDef _bulgarian() => MotionDef(
  id: 'bulgarian_split_squat',
  title: 'Bulgarian Split Squat',
  cue:
      'Rear foot on the bench, front foot far enough forward that the knee '
      'stays over the ankle. Lower straight down until the front thigh is '
      'about parallel, then drive up through the front heel.',
  pose: (d) {
    final hip = Offset(-0.12, _lerpD(0.92, 0.55, d));
    const theta = 0.15;
    final shoulder = hip + polar(kTrunk, theta);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: _floorAnkle,
      wrist: Offset(shoulder.dx, shoulder.dy - 0.56),
      farAnkle: const Offset(-0.80, 0.52),
      farKneePole: const Offset(0, -1),
      farHeel: const Offset(-0.88, 0.47),
      farToe: const Offset(-0.62, 0.47),
      props: [
        const Prop.rect(Offset(-1.05, 0.38), Offset(-0.55, 0.45)),
        const Prop.line(Offset(-0.95, 0.38), Offset(-0.95, 0.0)),
        const Prop.line(Offset(-0.65, 0.38), Offset(-0.65, 0.0)),
        Prop.circle(Offset(shoulder.dx, shoulder.dy - 0.56), 0.06),
      ],
    );
  },
);

MotionDef _catCow() => MotionDef(
  id: 'cat_cow_stretch',
  title: 'Cat-Cow Spinal Mobility',
  cycleSeconds: 4,
  cue:
      'On hands and knees. Inhale: let the belly drop and lift the chest and '
      'tailbone (cow). Exhale: round the back toward the ceiling and tuck the '
      'chin and tailbone (cat). Move slowly.',
  pose: (d) {
    // d 0 = cow (sag), 1 = cat (round).
    const hand = Offset(0.36, 0.04);
    const shoulder = Offset(0.36, 0.60);
    const hip = Offset(-0.12, 0.47);
    const knee = Offset(-0.12, 0.04);
    final arch = _lerpD(-0.10, 0.15, d);
    final mid = Offset.lerp(hip, shoulder, 0.5)! + Offset(0, arch);
    List<Offset> spine = [];
    for (var i = 0; i <= 6; i++) {
      final t = i / 6;
      final a = Offset.lerp(hip, mid, t)!;
      final b = Offset.lerp(mid, shoulder, t)!;
      spine.add(Offset.lerp(a, b, t)!);
    }
    final headDir = Offset(0.7, _lerpD(0.45, -0.55, d));
    final head = shoulder + headDir / headDir.distance * kHeadOffset;
    return Pose(
      hip: hip,
      knee: knee,
      ankle: const Offset(-0.55, 0.06),
      heel: const Offset(-0.60, 0.04),
      toe: const Offset(-0.50, 0.02),
      shoulder: shoulder,
      elbow: twoBone(
        shoulder,
        hand,
        kUpperArm,
        kForeArm,
        const Offset(-1, 0),
      ).mid,
      wrist: hand,
      head: head,
      focus: head,
      spine: spine,
    );
  },
);

// ---------------------------------------------------------------- cardio
MotionDef _bike(
  String id,
  String title, {
  double seconds = 1.6,
  double lean = 1.0,
}) => MotionDef(
  id: id,
  title: title,
  cyclic: true,
  cycleSeconds: seconds,
  cue:
      'Saddle height so the leg is almost straight at the bottom of the '
      'stroke. Pedal in smooth circles, pushing down and pulling through '
      'the top, with a light grip and relaxed shoulders.',
  pose: (d) {
    const c = Offset(0.0, 0.34);
    const r = 0.17;
    final a = d * 2 * math.pi;
    final p1 = c + Offset(r * math.sin(a), r * math.cos(a));
    final p2 = c + Offset(-r * math.sin(a), -r * math.cos(a));
    final ankle = p1 + const Offset(-0.02, 0.05);
    final far = p2 + const Offset(-0.02, 0.05);
    const hip = Offset(-0.16, 0.95);
    return person(
      hip: hip,
      trunkAngle: lean,
      ankle: ankle,
      wrist: const Offset(0.52, 0.98),
      kneePole: const Offset(1, 0.2),
      elbowPole: const Offset(0, -1),
      heel: ankle + const Offset(-0.06, -0.03),
      toe: ankle + const Offset(0.14, -0.02),
      farAnkle: far,
      farHeel: far + const Offset(-0.06, -0.03),
      farToe: far + const Offset(0.14, -0.02),
      focus: p1,
      props: [
        const Prop.circle(Offset(-0.62, 0.34), 0.34, filled: false),
        const Prop.circle(Offset(0.62, 0.34), 0.34, filled: false),
        const Prop.line(Offset(-0.62, 0.34), c),
        const Prop.line(c, Offset(0.62, 0.34)),
        const Prop.line(c, Offset(-0.20, 0.85)),
        const Prop.line(Offset(-0.20, 0.85), Offset(0.52, 0.88)),
        const Prop.line(Offset(0.52, 0.88), Offset(0.62, 0.34)),
        Prop.line(c, p1),
        const Prop.rect(Offset(-0.30, 0.90), Offset(-0.06, 0.94)),
      ],
    );
  },
);

MotionDef _rowingMachine(String id, String title) => MotionDef(
  id: id,
  title: title,
  firstHalf: MotionPhase.concentric,
  cue:
      'The drive: legs first, then lean back, then arms. The recovery is the '
      'reverse: arms, body over, then knees. Keep the back flat and the '
      'handle path level.',
  pose: (d) {
    final e1 = _clamp01(d / 0.6);
    final e2 = _clamp01((d - 0.35) / 0.45);
    final e3 = _clamp01((d - 0.70) / 0.30);
    final hip = Offset(_lerpD(0.10, -0.26, e1), 0.30);
    final theta = _lerpD(0.40, -0.40, e2);
    final shoulder = hip + polar(kTrunk, theta);
    final wrist =
        shoulder + Offset(_lerpD(0.53, 0.12, e3), _lerpD(-0.14, -0.30, e3));
    const ankle = Offset(0.58, 0.22);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: ankle,
      wrist: wrist,
      kneePole: const Offset(0, 1),
      elbowPole: const Offset(0, -1),
      heel: const Offset(0.52, 0.12),
      toe: const Offset(0.70, 0.18),
      props: [
        Prop.rect(Offset(hip.dx - 0.14, 0.18), Offset(hip.dx + 0.12, 0.26)),
        const Prop.line(Offset(-0.60, 0.12), Offset(0.60, 0.12)),
        const Prop.circle(Offset(0.95, 0.40), 0.30, filled: false),
        Prop.line(wrist, const Offset(0.92, 0.40), dashed: true),
      ],
    );
  },
);

MotionDef _hipFlexor() => MotionDef(
  id: 'hip_flexor_stretch',
  title: 'Kneeling Hip Flexor Stretch',
  isometric: true,
  firstHalf: MotionPhase.hold,
  cue:
      'Half-kneeling with the front shin vertical. Tuck the tailbone under and '
      'shift the hips gently forward until you feel the front of the rear hip '
      'stretch. Hold and breathe; this is a held stretch.',
  pose: (d) {
    final hip = Offset(_lerpD(-0.06, -0.01, d), 0.58);
    const shoulder0 = 0.0;
    return person(
      hip: hip,
      trunkAngle: shoulder0,
      ankle: const Offset(0.42, kAnkleHeight),
      wrist: hip + const Offset(0.06, 0.08),
      kneePole: const Offset(0.4, 1),
      elbowPole: const Offset(-1, -0.2),
      farAnkle: const Offset(-0.70, 0.10),
      farKneePole: const Offset(0, -1),
      farHeel: const Offset(-0.76, 0.07),
      farToe: const Offset(-0.54, 0.04),
    );
  },
);

// -------------------------------------------------------------- registry

/// Exercise id to its demonstration.
class ExerciseMotions {
  const ExerciseMotions._();

  static final Map<String, MotionDef> _all = _build();

  static Map<String, MotionDef> _build() {
    final defs = <MotionDef>[
      _squat('barbell_back_squat', 'Barbell Back Squat'),
      _airSquat('bodyweight_squat', 'Bodyweight Air Squat'),
      _gobletSquat('dumbbell_goblet_squat', 'Dumbbell Goblet Squat'),
      _deadlift('conventional_deadlift', 'Conventional Barbell Deadlift'),
      _rdl('romanian_deadlift', 'Barbell Romanian Deadlift', barbell: true),
      _rdl('dumbbell_rdl', 'Dumbbell Romanian Deadlift', barbell: false),
      _benchPress('bench_press', 'Barbell Bench Press', dumbbells: false),
      _benchPress(
        'dumbbell_bench_press',
        'Dumbbell Bench Press',
        dumbbells: true,
      ),
      _inclinePress(
        'incline_bench_press',
        'Incline Barbell Bench Press',
        dumbbells: false,
      ),
      _inclinePress(
        'incline_dumbbell_press',
        'Incline Dumbbell Press',
        dumbbells: true,
      ),
      _pushUp(),
      _overheadPress('overhead_press', 'Barbell Overhead Press', seated: false),
      _overheadPress(
        'dumbbell_shoulder_press',
        'Seated Dumbbell Shoulder Press',
        seated: true,
      ),
      _curl('bicep_curl', 'Dumbbell Bicep Curl'),
      _curl('barbell_bicep_curl', 'Barbell Bicep Curl'),
      _curl(
        'hammer_curl',
        'Dumbbell Hammer Curl',
        grip: 'palms facing each other',
      ),
      _curl('cable_bicep_curl', 'Cable Bicep Curl', cable: true),
      _bentRow(),
      _seatedRow(),
      _pullUp('pull_ups', 'Pull-ups', 'palms facing away'),
      _pullUp('chin_ups', 'Chin-ups', 'palms facing you'),
      _latPulldown(),
      _pushdown(),
      _skullCrusher(),
      _legExtension(),
      _calfRaise(),
      _plank(),
      _hangingLegRaise(),
      _bulgarian(),
      _walkingLunge(),
      _run('outdoor_run', 'Outdoor Run'),
      _run('treadmill_run', 'Treadmill Run'),
      _run(
        'sprint_intervals',
        'Sprint Intervals (HIIT)',
        stride: 0.70,
        lift: 0.36,
        hipBase: 0.81,
        lean: 0.22,
        seconds: 0.8,
      ),
      _run(
        'jogging',
        'Recovery Jog',
        stride: 0.45,
        lift: 0.26,
        lean: 0.08,
        seconds: 1.3,
      ),
      _bike('stationary_bike', 'Stationary Bike'),
      _bike('outdoor_cycling', 'Outdoor Cycling', lean: 1.05),
      _bike('hiit_cycling', 'HIIT Bike Sprints', seconds: 0.9, lean: 1.1),
      _rowingMachine('rowing_machine', 'Rowing Machine'),
      _rowingMachine('rowing_intervals', 'Rowing 500m Sprints'),
      _jumpRope(),
      _mountainClimber(),
      _catCow(),
      _hipFlexor(),
      _chestDips(),
      _facePulls(),
      _dumbbellRow(),
      _preacherCurl(),
      _concentrationCurl(),
      _inclineCurl(),
      _overheadTricep(),
      _kickbacks(),
      _hamstringCurl(),
      _seatedCalfRaise(),
      _legPress(),
      _calfPress(),
      _chestPressMachine(),
      _couchStretch(),
      _burpees(),
      _lateralRaise('lateral_raise', 'Dumbbell Lateral Raise'),
      _lateralRaise('cable_lateral_raise', 'Cable Lateral Raise', cable: true),
      _rearDeltFly(),
      _dumbbellChestFly(),
      _cableChestFly(),
    ];
    return {for (final d in defs) d.id: d};
  }

  /// Why an exercise has no demonstration yet. Stated plainly instead of
  /// showing a figure that might teach the wrong form.
  static const Map<String, String> unavailable = {
    'arnold_press':
        'The forearm rotation that defines this press cannot be drawn '
        'accurately with a stick figure.',
    'hiit_circuit':
        'A circuit of different movements, so there is no single form to show.',
    'football': 'A sport, not a single repeatable movement.',
    'basketball': 'A sport, not a single repeatable movement.',
    'swimming': 'The stroke is not drawn from the side on land.',
    'boxing': 'A skill drill with many techniques, not a single movement.',
    'world_greatest_stretch':
        'It chains a lunge, a reach and a spinal rotation; the rotation '
        'cannot be shown accurately from one viewpoint.',
    'foam_rolling_full_body':
        'A set of different rolling positions, not one repeatable movement.',
    'doorway_chest_stretch':
        'The stretch happens by stepping forward through the doorway, which '
        'neither a side nor a front view can show.',
  };

  static final Map<String, MotionDef> _front = _buildFrontViews(
    (id) => _all[id]!,
  );

  /// Every viewpoint that exists for an exercise, the default one first.
  /// Only views that are really drawn are listed, so a screen can offer a
  /// switch exactly when there is more than one.
  static List<MotionDef> viewsFor(String id) {
    final primary = _all[id];
    if (primary == null) return const [];
    final extra = _front[id];
    return [primary, ?extra];
  }

  /// The demonstration for [id] seen from [view], or null if that view does
  /// not exist for it.
  static MotionDef? forIdView(String id, MotionView view) {
    for (final m in viewsFor(id)) {
      if (m.view == view) return m;
    }
    return null;
  }

  /// The views available for [id], in the order they are offered.
  static List<MotionView> availableViews(String id) => [
    for (final m in viewsFor(id)) m.view,
  ];

  static MotionDef? forId(String id) => _all[id];
  static bool has(String id) => _all.containsKey(id);
  static Iterable<MotionDef> get all => _all.values;
  static String? unavailableReason(String id) => unavailable[id];
}
