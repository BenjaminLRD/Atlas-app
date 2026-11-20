part of 'exercise_motion.dart';

// More demonstrations: the rest of the side-view exercises, the walking
// lunge and running cycles with a moving ground, and the front, foot-end and
// top views for movements that happen across the body.

// ----------------------------------------------------------------- feet

class _FootPose {
  final Offset ankle;
  final Offset heel;
  final Offset toe;
  const _FootPose(this.ankle, this.heel, this.toe);
}

/// A foot that pivots about the ball of the foot; [pitch] raises the heel.
_FootPose _pitchedFoot(Offset ball, double pitch) {
  final c = math.cos(pitch);
  final s = math.sin(pitch);
  return _FootPose(
    ball + Offset(-kToe * c + kAnkleHeight * s, kToe * s + kAnkleHeight * c),
    ball + Offset(-(kToe + kHeel) * c, (kToe + kHeel) * s),
    ball,
  );
}

// -------------------------------------------------------- walking lunge

/// Two steps (right then left). The body stays in the middle of the picture
/// and the ground slides past, so each foot is planted while it is the front
/// foot and travels forward while it swings through.
Pose _walkingLungePose(double d) {
  const step = 0.75;
  final k = d < 0.5 ? 0 : 1;
  final s = d < 0.5 ? d * 2 : (d - 0.5) * 2;
  final fx = step * (1 + k); // planted foot, ankle x when flat
  final rx = fx - step; // where the swinging foot starts

  final hipX = s <= 0.5
      ? fx - step / 2 + (step / 2) * ease(s / 0.5)
      : fx + (step / 2) * ease((s - 0.5) / 0.5);
  final double hipY;
  if (s < 0.45) {
    hipY = _lerpD(0.50, 0.84, ease(s / 0.45));
  } else if (s < 0.55) {
    hipY = 0.84;
  } else {
    hipY = _lerpD(0.84, 0.50, ease((s - 0.55) / 0.45));
  }

  // Planted foot: flat until the hips pass over it, then the heel lifts.
  final plantPitch = s < 0.55 ? 0.0 : 0.9 * ease((s - 0.55) / 0.45);
  final planted = _pitchedFoot(Offset(fx + kToe, 0.0), plantPitch);

  // Swinging foot: toes push off, the foot travels a double step forward and
  // lands heel first at s = 0.78.
  final u = _clamp01((s - 0.12) / 0.66);
  final swingPitch = 0.9 * (1 - ease(_clamp01(s / 0.78)));
  final swing = _pitchedFoot(
    Offset(rx + kToe + 2 * step * ease(u), 0.22 * math.sin(math.pi * u)),
    swingPitch,
  );

  final near = k == 0 ? planted : swing;
  final far = k == 0 ? swing : planted;

  const theta = 0.06;
  final hip = Offset(hipX, hipY);
  final shoulder = hip + polar(kTrunk, theta);
  final wrist = Offset(shoulder.dx, shoulder.dy - 0.56);
  final pose = person(
    hip: hip,
    trunkAngle: theta,
    ankle: near.ankle,
    heel: near.heel,
    toe: near.toe,
    wrist: wrist,
    farAnkle: far.ankle,
    farHeel: far.heel,
    farToe: far.toe,
    farWrist: wrist,
    kneePole: const Offset(1, 0),
    farKneePole: const Offset(1, 0),
    props: [Prop.circle(wrist, 0.06)],
    focus: hip,
  );
  return pose.translated(Offset(-hipX, 0), travel: hipX);
}

MotionDef _walkingLunge() => MotionDef(
  id: 'walking_lunges',
  title: 'Dumbbell Walking Lunges',
  cyclic: true,
  cycleSeconds: 4.4,
  travelPerCycle: 0.75 * 2,
  note: 'Both legs shown; ground marks show travel.',
  cue:
      'Take a long step, keep the torso tall and lower until both knees are '
      'near 90 degrees with the back knee just above the floor. Push through '
      'the front foot, stand tall and step through with the other leg.',
  pose: _walkingLungePose,
);

// -------------------------------------------------------------- running

Pose _runPose(
  double d, {
  required double stride,
  required double lift,
  required double lean,
  required double hipBase,
}) {
  const stance = 0.4;
  Offset ankleFor(double phase) {
    final u = phase - phase.floorToDouble();
    if (u < stance) {
      // Foot on the ground, moving backward under the body.
      return Offset(0.45 * stride - stride * (u / stance), kAnkleHeight);
    }
    final w = (u - stance) / (1 - stance);
    return Offset(
      -0.55 * stride + stride * ease(w),
      kAnkleHeight + lift * math.pow(math.sin(math.pi * w), 1.3),
    );
  }

  final hip = Offset(0.0, hipBase + 0.05 * math.cos(4 * math.pi * (d - 0.45)));
  final shoulder = hip + polar(kTrunk, lean);
  final near = ankleFor(d);
  final far = ankleFor(d + 0.5);
  double armAngle(double ph) => -0.85 * math.cos(2 * math.pi * ph);
  Offset elbowFor(double a) => shoulder + down(kUpperArm, a);
  Offset wristFor(double a) => elbowFor(a) + down(kForeArm, a + 1.45);
  final an = armAngle(d);
  final af = armAngle(d + 0.5);
  final pose = person(
    hip: hip,
    trunkAngle: lean,
    ankle: near,
    heel: near + const Offset(-0.07, -0.05),
    toe: near + const Offset(0.17, -0.07),
    wrist: wristFor(an),
    elbowAt: elbowFor(an),
    kneePole: const Offset(1, 0.1),
    farAnkle: far,
    farHeel: far + const Offset(-0.07, -0.05),
    farToe: far + const Offset(0.17, -0.07),
    farWrist: wristFor(af),
    farElbowAt: elbowFor(af),
    farKneePole: const Offset(1, 0.1),
    focus: hip,
  );
  return pose.translated(Offset.zero, travel: stride / stance * d);
}

MotionDef _run(
  String id,
  String title, {
  double stride = 0.55,
  double lift = 0.32,
  double lean = 0.12,
  double hipBase = 0.79,
  double seconds = 1.1,
}) => MotionDef(
  id: id,
  title: title,
  cyclic: true,
  cycleSeconds: seconds,
  travelPerCycle: stride / 0.4,
  note: 'Ground marks show the body moving forward.',
  cue:
      'Tall posture with a slight forward lean from the ankles, quick '
      'light steps landing under the hips, elbows bent about 90 degrees '
      'and swinging back and forth, not across the body.',
  pose: (d) =>
      _runPose(d, stride: stride, lift: lift, lean: lean, hipBase: hipBase),
);

// ------------------------------------------------------------ jump rope

MotionDef _jumpRope() => MotionDef(
  id: 'jump_rope',
  title: 'Jump Rope',
  cyclic: true,
  cycleSeconds: 0.9,
  cue:
      'Elbows close to the ribs, wrists doing the turning. Hop on the balls of '
      'the feet just high enough for the rope to pass, landing softly.',
  pose: (d) {
    final a = d * 2 * math.pi;
    // The rope passes under the feet when they are at the top of the hop.
    final hop = 0.07 * (0.5 + 0.5 * math.cos(a));
    final hip = Offset(0.0, 0.92 + hop);
    final wrist =
        Offset(0.24, 1.02 + hop) +
        Offset(0.04 * math.cos(a), 0.04 * math.sin(a));
    // Seen from the side the rope is a loop through the hands.
    const r = 0.46;
    final centre = wrist + Offset(r * math.sin(a), -r * math.cos(a));
    final rope = <Prop>[];
    const n = 28;
    for (var i = 0; i < n; i++) {
      final a0 = i * 2 * math.pi / n;
      final a1 = (i + 1) * 2 * math.pi / n;
      rope.add(
        Prop.line(
          centre + Offset(r * math.sin(a0), r * math.cos(a0)),
          centre + Offset(r * math.sin(a1), r * math.cos(a1)),
        ),
      );
    }
    final ankle = Offset(0.0, kAnkleHeight + 1.6 * hop);
    return person(
      hip: hip,
      trunkAngle: 0.0,
      ankle: ankle,
      toe: ankle + const Offset(0.15, -0.09),
      heel: ankle + const Offset(-0.05, -0.02),
      wrist: wrist,
      elbowPole: const Offset(-1, -0.3),
      props: rope,
      focus: wrist,
    );
  },
);

// ----------------------------------------------------------- burpees

class _BurpeeKey {
  final Offset hip;
  final double theta;
  final Offset ankle;
  final Offset? wrist; // null: hands hanging by the sides
  final bool overhead;
  final double plank; // 1 when the feet are on their toes
  const _BurpeeKey(
    this.hip,
    this.theta,
    this.ankle, {
    this.wrist,
    this.overhead = false,
    this.plank = 0,
  });
}

const _bStand = _BurpeeKey(Offset(0, 0.92), 0.02, Offset(0, kAnkleHeight));
const _bSquat = _BurpeeKey(
  Offset(-0.25, 0.42),
  1.3,
  Offset(0, kAnkleHeight),
  wrist: Offset(0.35, 0.04),
);
const _bPlank = _BurpeeKey(
  Offset(-0.127, 0.419),
  1.277,
  Offset(-0.95, 0.17),
  wrist: Offset(0.366, 0.04),
  plank: 1,
);
const _bDown = _BurpeeKey(
  Offset(-0.09, 0.189),
  1.547,
  Offset(-0.95, 0.17),
  wrist: Offset(0.366, 0.04),
  plank: 1,
);
const _bJump = _BurpeeKey(
  Offset(0.0, 1.14),
  0.0,
  Offset(0.0, 0.30),
  overhead: true,
);

Pose _burpeePose(double d) {
  const times = [0.0, 0.12, 0.24, 0.34, 0.44, 0.56, 0.68, 0.80, 0.94, 1.0];
  const keys = [
    _bStand,
    _bSquat,
    _bPlank,
    _bDown,
    _bPlank,
    _bSquat,
    _bStand,
    _bJump,
    _bStand,
    _bStand,
  ];
  var i = 0;
  while (i < times.length - 2 && d >= times[i + 1]) {
    i++;
  }
  final a = keys[i];
  final b = keys[i + 1];
  final k = ease((d - times[i]) / (times[i + 1] - times[i]));

  final hip = Offset.lerp(a.hip, b.hip, k)!;
  final theta = _lerpD(a.theta, b.theta, k);
  var ankle = Offset.lerp(a.ankle, b.ankle, k)!;
  // The feet travel through the air when they jump back or in.
  final jumped = (a.ankle.dx - b.ankle.dx).abs() > 0.5;
  if (jumped) ankle += Offset(0, 0.30 * math.sin(math.pi * k));
  final plank = _lerpD(a.plank, b.plank, k);
  final shoulder = hip + polar(kTrunk, theta);

  Offset handsFor(_BurpeeKey key) =>
      key.wrist ??
      (key.overhead
          ? Offset(shoulder.dx + 0.03, shoulder.dy + 0.55)
          : Offset(shoulder.dx + 0.03, shoulder.dy - 0.55));
  var wrist = Offset.lerp(handsFor(a), handsFor(b), k)!;
  // Hands reach for the floor but never further than the arm allows.
  final reach = wrist - shoulder;
  if (reach.distance > 0.56) wrist = shoulder + reach / reach.distance * 0.56;

  final heelFlat = const Offset(-kHeel, -kAnkleHeight);
  final toeFlat = const Offset(kToe, -kAnkleHeight);
  final heelPlank = const Offset(-0.04, -0.05);
  final toePlank = const Offset(0.05, -0.17);
  return person(
    hip: hip,
    trunkAngle: theta,
    ankle: ankle,
    heel: ankle + Offset.lerp(heelFlat, heelPlank, plank)!,
    toe: ankle + Offset.lerp(toeFlat, toePlank, plank)!,
    wrist: wrist,
    kneePole: const Offset(1, 0.3),
    elbowPole: Offset.lerp(const Offset(0, -1), const Offset(-1, 0.4), plank)!,
    focus: hip,
  );
}

MotionDef _burpees() => MotionDef(
  id: 'burpees',
  title: 'Burpees',
  cyclic: true,
  cycleSeconds: 3.6,
  note: 'Simplified side view of one full repetition.',
  cue:
      'Squat and place the hands on the floor, jump the feet back to a '
      'plank, lower the chest, press up, jump the feet back in, then jump '
      'up with the arms overhead.',
  pose: _burpeePose,
);

// -------------------------------------------------------- mountain climber

MotionDef _mountainClimber() => MotionDef(
  id: 'mountain_climbers',
  title: 'Mountain Climbers',
  cyclic: true,
  cycleSeconds: 1.2,
  note: 'A simplified side-view cycle.',
  cue:
      'Strong plank, hands under the shoulders and hips level. Drive one knee '
      'toward the chest, then switch quickly, keeping the hips from bouncing.',
  pose: (d) {
    final a = d * 2 * math.pi;
    const wrist = Offset(0.35, 0.04);
    const shoulder = Offset(0.35, 0.60);
    const hip = Offset(-0.15, 0.46);
    Offset ankleAt(double phase) {
      final k = 0.5 - 0.5 * math.cos(phase);
      final base = Offset.lerp(
        const Offset(-0.90, 0.16),
        const Offset(-0.02, 0.30),
        k,
      )!;
      // The foot lifts as it travels instead of dragging along the floor.
      return base + Offset(0, 0.10 * math.sin(math.pi * k));
    }

    final near = ankleAt(a);
    final far = ankleAt(a + math.pi);
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: near,
      wrist: wrist,
      kneePole: const Offset(0.3, -1),
      elbowPole: const Offset(-1, 0.2),
      heel: near + const Offset(-0.07, -0.05),
      toe: near + const Offset(0.12, -0.10),
      farAnkle: far,
      farKneePole: const Offset(0.3, -1),
      farHeel: far + const Offset(-0.07, -0.05),
      farToe: far + const Offset(0.12, -0.10),
      focus: near,
    );
  },
);

// ------------------------------------------------------------ chest dips

MotionDef _chestDips() => MotionDef(
  id: 'chest_dips',
  title: 'Parallel Bar Dips',
  cue:
      'Support yourself on straight arms, lean the torso forward and bend '
      'the knees behind you. Lower until the upper arms are about parallel '
      'to the floor with the elbows tracking back, then press up to lockout.',
  pose: (d) {
    const wrist = Offset(0.05, 1.05);
    final shoulder = Offset(_lerpD(0.07, 0.23, d), _lerpD(1.616, 1.41, d));
    final theta = _lerpD(0.20, 0.40, d);
    final hip = shoulder - polar(kTrunk, theta);
    final ankle = hip + const Offset(-0.42, -0.55);
    return person(
      hip: hip,
      shoulderAt: shoulder,
      ankle: ankle,
      heel: ankle + const Offset(0.05, 0.0),
      toe: ankle + const Offset(-0.15, -0.05),
      wrist: wrist,
      elbowPole: const Offset(-1, 0),
      kneePole: const Offset(0.5, -1),
      focus: shoulder,
      props: const [
        Prop.line(Offset(-0.10, 1.05), Offset(0.40, 1.05)),
        Prop.line(Offset(0.40, 1.05), Offset(0.40, 0.0)),
        Prop.line(Offset(-0.12, 0.0), Offset(0.62, 0.0)),
      ],
    );
  },
);

// ------------------------------------------------------------ face pulls

MotionDef _facePulls() => MotionDef(
  id: 'face_pulls',
  title: 'Cable Face Pulls',
  firstHalf: MotionPhase.concentric,
  cue:
      'Cable at upper-chest to face height, arms straight toward it. Pull the '
      'rope toward your face, splitting the ends apart, with the elbows high '
      'and wide, squeeze the shoulder blades, then let the arms return.',
  pose: (d) {
    const hip = Offset(0.0, 0.92);
    const theta = -0.08;
    final shoulder = hip + polar(kTrunk, theta);
    final start = shoulder + const Offset(0.54, 0.02);
    const end = Offset(0.10, 1.60);
    final wrist = _lerp(start, end, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: _floorAnkle,
      wrist: wrist,
      elbowPole: const Offset(0, 1),
      props: [
        const Prop.circle(Offset(1.05, 1.55), 0.06, filled: false),
        Prop.line(wrist, const Offset(1.02, 1.55)),
        Prop.circle(wrist, 0.035),
      ],
    );
  },
);

// ------------------------------------------------------ single-arm row

MotionDef _dumbbellRow() => MotionDef(
  id: 'dumbbell_row',
  title: 'Single-Arm Dumbbell Row',
  firstHalf: MotionPhase.concentric,
  cue:
      'One knee and hand on the bench, back flat and nearly parallel to the '
      'floor. Row the dumbbell toward the hip, elbow close to the body, '
      'squeeze the shoulder blade, then lower under control.',
  pose: (d) {
    const hip = Offset(-0.35, 0.85);
    const theta = 1.35;
    final shoulder = hip + polar(kTrunk, theta);
    final start = shoulder + const Offset(0.02, -0.55);
    const end = Offset(-0.08, 0.90);
    final wrist = _lerp(start, end, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(-0.40, kAnkleHeight),
      kneePole: const Offset(1, 0),
      wrist: wrist,
      elbowPole: const Offset(-1, 0.4),
      farAnkle: const Offset(-0.53, 0.50),
      farKneePole: const Offset(1, -0.2),
      farHeel: const Offset(-0.58, 0.47),
      farToe: const Offset(-0.38, 0.47),
      farWrist: const Offset(0.30, 0.48),
      farElbowPole: const Offset(-1, 0.2),
      props: [
        const Prop.rect(Offset(-0.60, 0.38), Offset(0.45, 0.45)),
        const Prop.line(Offset(-0.50, 0.38), Offset(-0.50, 0.0)),
        const Prop.line(Offset(0.35, 0.38), Offset(0.35, 0.0)),
        Prop.circle(wrist, 0.07),
      ],
    );
  },
);

// ------------------------------------------------------ curl variations

MotionDef _preacherCurl() => MotionDef(
  id: 'preacher_curl',
  title: 'Preacher Curl (Scott Curl)',
  firstHalf: MotionPhase.concentric,
  cue:
      'Upper arms flat on the pad, armpits at the top. Curl the weight up by '
      'bending only the elbows, squeeze at the top, then lower slowly to '
      'almost straight without letting the weight drop.',
  pose: (d) {
    const hip = Offset(-0.55, 0.50);
    const theta = 0.25;
    final shoulder = hip + polar(kTrunk, theta);
    const u = Offset(0.6, -0.8); // along the pad, down and forward
    const n = Offset(0.8, 0.6); // pad surface, up and forward
    final elbow = shoulder + u * kUpperArm;
    final psi = _lerpD(0.68, 2.30, d);
    final wrist =
        elbow + Offset(kForeArm * math.sin(psi), -kForeArm * math.cos(psi));
    final pad0 = shoulder - u * 0.20 - n * 0.05;
    final pad1 = elbow + u * 0.12 - n * 0.05;
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(-0.10, kAnkleHeight),
      wrist: wrist,
      elbowAt: elbow,
      kneePole: const Offset(0.3, 1),
      props: [
        const Prop.rect(Offset(-0.70, 0.43), Offset(-0.40, 0.48)),
        const Prop.line(Offset(-0.55, 0.43), Offset(-0.55, 0.0)),
        Prop.line(pad0, pad1),
        Prop.line(
          Offset.lerp(pad0, pad1, 0.5)! - n * 0.05,
          Offset(Offset.lerp(pad0, pad1, 0.5)!.dx - 0.05, 0.0),
        ),
        Prop.circle(wrist, 0.06),
      ],
    );
  },
);

MotionDef _concentrationCurl() => MotionDef(
  id: 'concentration_curl',
  title: 'Dumbbell Concentration Curl',
  firstHalf: MotionPhase.concentric,
  cue:
      'Seated, lean forward and brace the back of the working upper arm on '
      'the inner thigh. Curl the dumbbell toward the shoulder, squeeze, then '
      'lower until the arm is almost straight.',
  pose: (d) {
    const hip = Offset(-0.40, 0.50);
    const theta = 0.90;
    final shoulder = hip + polar(kTrunk, theta);
    final elbow = shoulder + down(kUpperArm, 0.12);
    final psi = _lerpD(0.05, 2.35, d);
    final wrist =
        elbow + Offset(kForeArm * math.sin(psi), -kForeArm * math.cos(psi));
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.05, kAnkleHeight),
      wrist: wrist,
      elbowAt: elbow,
      kneePole: const Offset(0.3, 1),
      props: [
        const Prop.rect(Offset(-0.60, 0.40), Offset(-0.15, 0.46)),
        const Prop.line(Offset(-0.45, 0.40), Offset(-0.45, 0.0)),
        Prop.circle(wrist, 0.07),
      ],
    );
  },
);

MotionDef _inclineCurl() => MotionDef(
  id: 'incline_dumbbell_curl',
  title: 'Incline Dumbbell Curl',
  firstHalf: MotionPhase.concentric,
  cue:
      'Back against the incline bench, arms hanging straight down behind the '
      'body for a deep stretch. Curl without swinging, keep the elbows back, '
      'then lower to a full stretch.',
  pose: (d) {
    const hip = Offset(-0.45, 0.50);
    const theta = -0.61;
    final shoulder = hip + polar(kTrunk, theta);
    final elbow = shoulder + down(kUpperArm, 0.10);
    final psi = _lerpD(0.08, 2.45, d);
    final wrist =
        elbow + Offset(kForeArm * math.sin(psi), -kForeArm * math.cos(psi));
    final dir = polar(1.0, theta);
    const back = Offset(-0.82, -0.573); // behind the back pad
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.05, kAnkleHeight),
      wrist: wrist,
      elbowAt: elbow,
      kneePole: const Offset(0.3, 1),
      props: [
        const Prop.rect(Offset(-0.62, 0.44), Offset(-0.30, 0.48)),
        const Prop.line(Offset(-0.45, 0.44), Offset(-0.45, 0.0)),
        Prop.line(hip + back * 0.08, hip + dir * 0.85 + back * 0.08),
        Prop.circle(wrist, 0.07),
      ],
    );
  },
);

// -------------------------------------------------------------- triceps

MotionDef _overheadTricep() => MotionDef(
  id: 'overhead_tricep_extension',
  title: 'Overhead Tricep Extension',
  cue:
      'Hold one dumbbell overhead with both hands, upper arms beside the '
      'ears and elbows pointing forward. Bend only the elbows to lower the '
      'weight behind the head, then press back up to straight arms.',
  pose: (d) {
    const hip = Offset(0.0, 0.92);
    final shoulder = hip + polar(kTrunk, 0.0);
    final elbow = shoulder + polar(kUpperArm, 0.13);
    final psi = _lerpD(0.05, 2.5, d);
    final wrist =
        elbow + Offset(-kForeArm * math.sin(psi), kForeArm * math.cos(psi));
    return person(
      hip: hip,
      trunkAngle: 0.0,
      ankle: _floorAnkle,
      wrist: wrist,
      elbowAt: elbow,
      props: [Prop.circle(wrist, 0.07)],
    );
  },
);

MotionDef _kickbacks() => MotionDef(
  id: 'tricep_kickbacks',
  title: 'Dumbbell Tricep Kickbacks',
  firstHalf: MotionPhase.concentric,
  cue:
      'Hinge forward with a flat back, upper arm held tight against the '
      'torso and parallel to the floor. Straighten only the elbow to kick '
      'the dumbbell back, squeeze the triceps, then bend to return.',
  pose: (d) {
    const hip = Offset(-0.25, 0.86);
    const theta = 1.3;
    final shoulder = hip + polar(kTrunk, theta);
    final elbow = shoulder + const Offset(-0.2995, 0.015);
    final phi = _lerpD(0.15, 1.50, d);
    final wrist =
        elbow + Offset(-kForeArm * math.sin(phi), -kForeArm * math.cos(phi));
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(-0.30, kAnkleHeight),
      kneePole: const Offset(1, 0.2),
      wrist: wrist,
      elbowAt: elbow,
      farAnkle: const Offset(0.05, kAnkleHeight),
      farKneePole: const Offset(1, 0.2),
      farWrist: const Offset(0.42, 0.49),
      farElbowPole: const Offset(-1, 0.2),
      props: [
        const Prop.rect(Offset(0.15, 0.38), Offset(0.80, 0.45)),
        const Prop.line(Offset(0.25, 0.38), Offset(0.25, 0.0)),
        const Prop.line(Offset(0.70, 0.38), Offset(0.70, 0.0)),
        Prop.circle(wrist, 0.07),
      ],
    );
  },
);

// ---------------------------------------------------------- leg machines

MotionDef _hamstringCurl() => MotionDef(
  id: 'hamstring_curl',
  title: 'Leg Curl Machine',
  firstHalf: MotionPhase.concentric,
  note: 'Seated machine; the lying version curls the same way.',
  cue:
      'Adjust the pad to sit just above the heels. Curl the heels down and '
      'back toward the glutes, squeeze the hamstrings, then return slowly '
      'without letting the stack drop.',
  pose: (d) {
    const hip = Offset(-0.05, 0.50);
    const knee = Offset(0.38, 0.52);
    final beta = _lerpD(1.35, -0.15, d);
    final s = Offset(math.sin(beta), -math.cos(beta)); // knee to ankle
    final f = Offset(math.cos(beta), math.sin(beta)); // front of the leg
    final ankle = knee + s * kShin;
    final pad = ankle - s * 0.07 - f * 0.06; // on the back of the calf
    return person(
      hip: hip,
      trunkAngle: -0.10,
      ankle: ankle,
      kneeAt: knee,
      wrist: const Offset(0.20, 0.52),
      elbowPole: const Offset(0, -1),
      heel: ankle - f * 0.03 - s * 0.04,
      toe: ankle + f * 0.15 - s * 0.02,
      focus: ankle,
      props: [
        const Prop.rect(Offset(-0.30, 0.40), Offset(0.35, 0.47)),
        const Prop.line(Offset(-0.32, 0.47), Offset(-0.38, 1.15)),
        const Prop.rect(Offset(0.10, 0.575), Offset(0.34, 0.63)),
        Prop.line(pad - s * 0.06, pad + s * 0.06),
      ],
    );
  },
);

MotionDef _seatedCalfRaise() => MotionDef(
  id: 'seated_calf_raise',
  title: 'Seated Calf Raise',
  firstHalf: MotionPhase.concentric,
  note: 'Seated machine; knees stay bent at about 90 degrees.',
  cue:
      'Seated with the pad on the lower thighs and the balls of the feet on '
      'the platform. Rise as high as you can, pause, then lower the heels '
      'for a full stretch.',
  pose: (d) {
    final phi = _lerpD(-0.25, 0.55, d);
    final foot = _pitchedFoot(const Offset(0.19, 0.0), phi);
    const hip = Offset(-0.43, 0.53);
    final chain = twoBone(hip, foot.ankle, kThigh, kShin, const Offset(0.3, 1));
    return person(
      hip: hip,
      trunkAngle: -0.05,
      ankle: foot.ankle,
      heel: foot.heel,
      toe: foot.toe,
      wrist: const Offset(-0.15, 0.64),
      kneePole: const Offset(0.3, 1),
      focus: chain.mid,
      props: [
        const Prop.rect(Offset(-0.02, -0.08), Offset(0.40, 0.0)),
        const Prop.rect(Offset(-0.62, 0.43), Offset(-0.28, 0.48)),
        const Prop.line(Offset(-0.45, 0.43), Offset(-0.45, 0.0)),
        Prop.rect(
          chain.mid + const Offset(-0.22, 0.01),
          chain.mid + const Offset(0.02, 0.09),
        ),
      ],
    );
  },
);

Pose _legPressPose(double d, {required bool calf}) {
  const hip = Offset(-0.50, 0.45);
  const theta = -0.80;
  const u = Offset(0.7071, 0.7071); // sled rail, up and away
  const v = Offset(-0.7071, 0.7071); // along the platform toward the head
  final Offset ankle;
  final Offset heel;
  final Offset toe;
  final Offset ball;
  if (calf) {
    final phi = _lerpD(-0.30, 0.55, d);
    ankle = hip + u * 0.83;
    final c = math.cos(phi);
    final s = math.sin(phi);
    final a = -kToe * c + kAnkleHeight * s;
    final b = kToe * s + kAnkleHeight * c;
    ball = ankle - v * a + u * b;
    heel = ball + v * (-(kToe + kHeel) * c) - u * ((kToe + kHeel) * s);
    toe = ball;
  } else {
    ankle = hip + u * _lerpD(0.83, 0.60, d);
    ball = ankle + v * kToe + u * kAnkleHeight;
    heel = ball - v * (kToe + kHeel);
    toe = ball;
  }
  const back = Offset(-0.697, -0.717);
  final dir = polar(1.0, theta);
  return person(
    hip: hip,
    trunkAngle: theta,
    ankle: ankle,
    heel: heel,
    toe: toe,
    wrist: const Offset(-0.45, 0.57),
    kneePole: const Offset(-0.3, 1),
    props: [
      Prop.line(ball - v * 0.32, ball + v * 0.26),
      Prop.line(ball - v * 0.32, ball - v * 0.32 - u * 0.85),
      Prop.line(
        hip + u * 0.25 + const Offset(0.707, -0.707) * 0.45,
        hip + u * 1.15 + const Offset(0.707, -0.707) * 0.45,
      ),
      Prop.line(hip + back * 0.08, hip + dir * 0.85 + back * 0.08),
      const Prop.rect(Offset(-0.70, 0.36), Offset(-0.28, 0.42)),
    ],
  );
}

MotionDef _legPress() => MotionDef(
  id: 'leg_press',
  title: 'Leg Press Sled',
  note: 'A typical 45-degree machine; yours may differ.',
  cue:
      'Feet shoulder-width on the platform, back and hips flat on the seat. '
      'Lower until the knees are about 90 degrees without the hips curling '
      'up, then press through the whole foot, stopping just short of locking '
      'the knees.',
  pose: (d) => _legPressPose(d, calf: false),
);

MotionDef _calfPress() => MotionDef(
  id: 'calf_press_leg_press',
  title: 'Calf Press on Leg Press Machine',
  firstHalf: MotionPhase.concentric,
  note: 'A typical 45-degree machine; yours may differ.',
  cue:
      'Legs almost straight, balls of the feet on the lower platform. Press '
      'the toes away as far as possible, pause, then let the heels come back '
      'for a full stretch. Only the ankles move.',
  pose: (d) => _legPressPose(d, calf: true),
);

MotionDef _chestPressMachine() => MotionDef(
  id: 'chest_press_machine',
  title: 'Machine Chest Press',
  firstHalf: MotionPhase.concentric,
  note: 'A typical seated machine; seat and handle layout vary.',
  cue:
      'Set the seat so the handles line up with the mid-chest. Back flat '
      'against the pad, shoulder blades pulled back. Press forward until the '
      'arms are almost straight, then return slowly with the elbows about 45 '
      'degrees from the body.',
  pose: (d) {
    const hip = Offset(-0.15, 0.50);
    const theta = -0.05;
    final shoulder = hip + polar(kTrunk, theta);
    final start = shoulder + const Offset(0.18, -0.12);
    final end = shoulder + const Offset(0.54, -0.12);
    final wrist = _lerp(start, end, d);
    return person(
      hip: hip,
      trunkAngle: theta,
      ankle: const Offset(0.30, kAnkleHeight),
      wrist: wrist,
      elbowPole: const Offset(0, -1),
      kneePole: const Offset(0.3, 1),
      props: [
        const Prop.rect(Offset(-0.35, 0.43), Offset(0.10, 0.48)),
        const Prop.line(Offset(-0.30, 0.48), Offset(-0.40, 1.30)),
        Prop.line(
          wrist + const Offset(0, -0.12),
          wrist + const Offset(0, 0.12),
        ),
      ],
    );
  },
);

// ----------------------------------------------------------- couch stretch

MotionDef _couchStretch() => MotionDef(
  id: 'couch_stretch',
  title: 'Couch Stretch',
  isometric: true,
  firstHalf: MotionPhase.hold,
  cue:
      'Back knee on the floor close to the couch with the shin up the '
      'cushions, front foot forward. Keep the torso tall, squeeze the glute '
      'of the back leg and shift the hips gently forward. Hold and breathe.',
  pose: (d) {
    const knee = Offset(-0.60, 0.04);
    final hip = knee + polar(kThigh, _lerpD(0.62, 0.80, d));
    final shoulder = hip + polar(kTrunk, -0.02);
    final front = Offset(hip.dx + 0.40, kAnkleHeight);
    return person(
      hip: hip,
      trunkAngle: -0.02,
      kneeAt: knee,
      ankle: Offset(-0.60, 0.47),
      heel: const Offset(-0.60, 0.42),
      toe: const Offset(-0.62, 0.61),
      wrist: hip + const Offset(0.06, 0.08),
      elbowPole: const Offset(-1, -0.2),
      farAnkle: front,
      farKneePole: const Offset(1, 0.5),
      props: [
        const Prop.rect(Offset(-0.90, 0.0), Offset(-0.66, 0.60)),
        const Prop.line(Offset(-0.95, 0.0), Offset(0.60, 0.0)),
      ],
      focus: shoulder,
    );
  },
);

// ======================================================== other viewpoints

Pose _frontFigure({
  double hipY = 0.92,
  required double shoulderY,
  double? headY,
  double shoulderHalf = 0.20,
  double hipHalf = 0.11,
  required Offset elbowR,
  required Offset wristR,
  required Offset elbowL,
  required Offset wristL,
  Offset? kneeR,
  Offset? kneeL,
  Offset? ankleR,
  Offset? ankleL,
  List<Prop> props = const [],
  Offset? focus,
}) {
  final hipR = Offset(hipHalf, hipY);
  final hipL = Offset(-hipHalf, hipY);
  final aR = ankleR ?? const Offset(0.14, kAnkleHeight);
  final aL = ankleL ?? const Offset(-0.14, kAnkleHeight);
  var err = 0.0;
  Offset kR;
  if (kneeR != null) {
    kR = kneeR;
  } else {
    final c = twoBone(hipR, aR, kThigh, kShin, const Offset(1, 0));
    kR = c.mid;
    err += c.error;
  }
  Offset kL;
  if (kneeL != null) {
    kL = kneeL;
  } else {
    final c = twoBone(hipL, aL, kThigh, kShin, const Offset(-1, 0));
    kL = c.mid;
    err += c.error;
  }
  return Pose(
    hip: hipR,
    knee: kR,
    ankle: aR,
    heel: aR + const Offset(0.0, -0.08),
    toe: aR + const Offset(0.10, -0.08),
    shoulder: Offset(shoulderHalf, shoulderY),
    elbow: elbowR,
    wrist: wristR,
    head: Offset(0, headY ?? shoulderY + 0.24),
    focus: focus ?? wristR,
    farKnee: kL,
    farAnkle: aL,
    farHeel: aL + const Offset(0.0, -0.08),
    farToe: aL + const Offset(-0.10, -0.08),
    farElbow: elbowL,
    farWrist: wristL,
    farShoulder: Offset(-shoulderHalf, shoulderY),
    farHip: hipL,
    props: props,
    reachError: err,
  );
}

/// An arm swung out sideways in the frontal plane: [phi] from hanging (0) to
/// horizontal (about 1.5), with the elbow slightly bent.
({Offset elbow, Offset wrist}) _sideArm(
  Offset shoulder,
  double side,
  double phi, {
  double bend = 0.20,
}) {
  final elbow =
      shoulder +
      Offset(side * kUpperArm * math.sin(phi), -kUpperArm * math.cos(phi));
  final wrist =
      elbow +
      Offset(
        side * kForeArm * math.sin(phi - bend),
        -kForeArm * math.cos(phi - bend),
      );
  return (elbow: elbow, wrist: wrist);
}

MotionDef _lateralRaise(String id, String title, {bool cable = false}) =>
    MotionDef(
      id: id,
      title: title,
      firstHalf: MotionPhase.concentric,
      view: MotionView.front,
      viewLabel: 'Front view',
      cue: cable
          ? 'Stand side-on to the low pulley, handle in the far hand. Raise '
                'the arm out to the side to shoulder height with a slight bend '
                'in the elbow, lead with the elbow, then lower slowly.'
          : 'Stand tall with a dumbbell in each hand. Raise the arms out to '
                'the sides to shoulder height with a slight bend in the '
                'elbows, lead with the elbows, then lower slowly.',
      pose: (d) {
        const sy = 1.44;
        final phi = _lerpD(0.04, 1.52, d);
        final r = _sideArm(const Offset(0.20, sy), 1, phi);
        if (cable) {
          // The other arm rests by the side.
          final rest = _sideArm(const Offset(-0.20, sy), -1, 0.10);
          const pulley = Offset(-0.62, 0.12);
          return _frontFigure(
            shoulderY: sy,
            elbowR: r.elbow,
            wristR: r.wrist,
            elbowL: rest.elbow,
            wristL: rest.wrist,
            props: [
              const Prop.circle(pulley, 0.05, filled: false),
              Prop.line(r.wrist, pulley, dashed: true),
              Prop.circle(r.wrist, 0.035),
            ],
          );
        }
        final l = _sideArm(const Offset(-0.20, sy), -1, phi);
        return _frontFigure(
          shoulderY: sy,
          elbowR: r.elbow,
          wristR: r.wrist,
          elbowL: l.elbow,
          wristL: l.wrist,
          props: [Prop.circle(r.wrist, 0.06), Prop.circle(l.wrist, 0.06)],
        );
      },
    );

MotionDef _rearDeltFly() => MotionDef(
  id: 'rear_delt_fly',
  title: 'Dumbbell Rear Delt Fly',
  firstHalf: MotionPhase.concentric,
  view: MotionView.front,
  viewLabel: 'Front view, torso hinged toward you',
  cue:
      'Hinge forward at the hips with a flat back, arms hanging with a slight '
      'bend. Raise the arms out to the sides, leading with the elbows and '
      'squeezing the shoulder blades, then lower slowly.',
  pose: (d) {
    // The torso leans toward the viewer, so it looks shorter from the front.
    final sy = 0.92 + kTrunk * math.cos(1.2);
    final phi = _lerpD(0.03, 1.45, d);
    final r = _sideArm(Offset(0.20, sy), 1, phi, bend: 0.18);
    final l = _sideArm(Offset(-0.20, sy), -1, phi, bend: 0.18);
    return _frontFigure(
      shoulderY: sy,
      headY: sy + 0.06,
      elbowR: r.elbow,
      wristR: r.wrist,
      elbowL: l.elbow,
      wristL: l.wrist,
      props: [Prop.circle(r.wrist, 0.06), Prop.circle(l.wrist, 0.06)],
    );
  },
);

MotionDef _dumbbellChestFly() => MotionDef(
  id: 'dumbbell_chest_fly',
  title: 'Dumbbell Chest Fly',
  view: MotionView.front,
  viewLabel: 'View from the foot of the bench',
  cue:
      'Lie on the bench with the dumbbells above the chest, palms facing in, '
      'elbows slightly bent. Open the arms in a wide arc until you feel a '
      'stretch across the chest, then bring the dumbbells back together '
      'above the chest.',
  pose: (d) {
    const benchTop = 0.45;
    const sy = benchTop + 0.12;
    final psi = _lerpD(-0.25, 1.45, d);
    ({Offset elbow, Offset wrist}) arm(double side) {
      final s = Offset(side * 0.20, sy);
      final e =
          s +
          Offset(side * kUpperArm * math.sin(psi), kUpperArm * math.cos(psi));
      final w =
          e +
          Offset(
            side * kForeArm * math.sin(psi - 0.12),
            kForeArm * math.cos(psi - 0.12),
          );
      return (elbow: e, wrist: w);
    }

    final r = arm(1);
    final l = arm(-1);
    return _frontFigure(
      hipY: 0.55,
      shoulderY: sy,
      headY: sy,
      elbowR: r.elbow,
      wristR: r.wrist,
      elbowL: l.elbow,
      wristL: l.wrist,
      kneeR: const Offset(0.17, 0.53),
      kneeL: const Offset(-0.17, 0.53),
      ankleR: const Offset(0.17, kAnkleHeight),
      ankleL: const Offset(-0.17, kAnkleHeight),
      props: [
        const Prop.rect(Offset(-0.17, 0.36), Offset(0.17, benchTop)),
        const Prop.line(Offset(-0.12, 0.36), Offset(-0.12, 0.0)),
        const Prop.line(Offset(0.12, 0.36), Offset(0.12, 0.0)),
        const Prop.rect(Offset(-0.21, benchTop), Offset(0.21, 0.62)),
        Prop.circle(r.wrist, 0.06),
        Prop.circle(l.wrist, 0.06),
      ],
    );
  },
);

MotionDef _cableChestFly() => MotionDef(
  id: 'cable_chest_fly',
  title: 'Cable Chest Fly / Crossover',
  view: MotionView.top,
  viewLabel: 'View from above',
  cue:
      'Stand between the pulleys with a staggered stance and a slight bend in '
      'the elbows. Sweep the hands forward in a wide hugging arc until they '
      'meet in front of the chest, squeeze, then open the arms back out '
      'under control.',
  pose: (d) {
    const sh = 0.20;
    Offset wrist(double side) =>
        Offset(side * _lerpD(0.72, 0.03, d), _lerpD(-0.02, 0.50, d));
    final wr = wrist(1);
    final wl = wrist(-1);
    final cr = twoBone(
      const Offset(sh, 0),
      wr,
      kUpperArm,
      kForeArm,
      const Offset(1, -0.6),
    );
    final cl = twoBone(
      const Offset(-sh, 0),
      wl,
      kUpperArm,
      kForeArm,
      const Offset(-1, -0.6),
    );
    const hipR = Offset(0.11, -0.28);
    return Pose(
      hip: hipR,
      knee: hipR,
      ankle: hipR,
      heel: hipR,
      toe: hipR,
      shoulder: const Offset(sh, 0),
      elbow: cr.mid,
      wrist: wr,
      head: const Offset(0, 0.03),
      focus: wr,
      farElbow: cl.mid,
      farWrist: wl,
      farShoulder: const Offset(-sh, 0),
      farHip: const Offset(-0.11, -0.28),
      reachError: cr.error + cl.error,
      props: [
        const Prop.circle(Offset(0.95, -0.20), 0.05, filled: false),
        const Prop.circle(Offset(-0.95, -0.20), 0.05, filled: false),
        Prop.line(wr, const Offset(0.95, -0.20), dashed: true),
        Prop.line(wl, const Offset(-0.95, -0.20), dashed: true),
        Prop.circle(wr, 0.035),
        Prop.circle(wl, 0.035),
      ],
    );
  },
);
