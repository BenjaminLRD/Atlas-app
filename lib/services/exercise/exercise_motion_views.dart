part of 'exercise_motion.dart';

// ====================================================== alternate viewpoints
//
// Some exercises can be watched from the side and from the front. The front
// view is built from the side motion, never drawn independently: every height
// (hip, knee, ankle, shoulder, head, and the hands when they are held on a
// bar) is taken from the side pose, and only the sideways position is added.
// That is an orthographic projection, so the two views always show the same
// movement and cannot drift apart. Limbs that swing toward the viewer (a
// squatting thigh, a curling forearm) therefore look shorter, exactly as they
// do in a photograph taken from the front.

List<Prop> _barbell(double y, {double half = 0.72}) => [
  Prop.line(Offset(-half, y), Offset(half, y)),
  Prop.rect(Offset(half - 0.02, y - 0.21), Offset(half + 0.03, y + 0.21)),
  Prop.rect(Offset(-half - 0.03, y - 0.21), Offset(-half + 0.02, y + 0.21)),
];

List<Prop> _dumbbellPair(Pose f) => [
  Prop.circle(f.wrist, 0.06),
  Prop.circle(f.farWrist!, 0.06),
];

/// The front-view companions of side-view demonstrations, by exercise id.
Map<String, MotionDef> _buildFrontViews(MotionDef Function(String) side) {
  final defs = <MotionDef>[
    _frontOfSide(
      side('barbell_back_squat'),
      ankleHalf: 0.19,
      wristHalf: (d) => 0.36,
      gripAtShoulder: true,
      elbowPole: const Offset(0.2, -1),
      props: (f) => _barbell(f.wrist.dy),
    ),
    _frontOfSide(
      side('bodyweight_squat'),
      ankleHalf: 0.17,
      armsProjected: true,
      elbowHalf: (d) => 0.24,
      wristHalf: (d) => 0.08,
    ),
    _frontOfSide(
      side('dumbbell_goblet_squat'),
      ankleHalf: 0.17,
      armsProjected: true,
      elbowHalf: (d) => 0.22,
      wristHalf: (d) => 0.07,
      props: (f) => [
        Prop.rect(
          Offset(-0.09, f.wrist.dy - 0.05),
          Offset(0.09, f.wrist.dy + 0.05),
        ),
      ],
    ),
    _frontOfSide(
      side('conventional_deadlift'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.24,
      wristHalf: (d) => 0.25,
      props: (f) => _barbell(f.wrist.dy),
    ),
    _frontOfSide(
      side('romanian_deadlift'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.24,
      wristHalf: (d) => 0.25,
      props: (f) => _barbell(f.wrist.dy),
    ),
    _frontOfSide(
      side('dumbbell_rdl'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.23,
      wristHalf: (d) => 0.24,
      props: _dumbbellPair,
    ),
    _frontOfSide(
      side('overhead_press'),
      ankleHalf: 0.14,
      wristHalf: (d) => 0.26,
      elbowPole: const Offset(0.8, -1),
      props: (f) => _barbell(f.wrist.dy),
    ),
    _frontOfSide(
      side('dumbbell_shoulder_press'),
      ankleHalf: 0.20,
      wristHalf: (d) => _lerpD(0.38, 0.25, d),
      elbowPole: const Offset(0.8, -1),
      props: _dumbbellPair,
    ),
    _frontOfSide(
      side('bicep_curl'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.23,
      wristHalf: (d) => 0.23,
      props: _dumbbellPair,
    ),
    _frontOfSide(
      side('hammer_curl'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.23,
      wristHalf: (d) => 0.23,
      props: _dumbbellPair,
    ),
    _frontOfSide(
      side('barbell_bicep_curl'),
      ankleHalf: 0.14,
      armsProjected: true,
      elbowHalf: (d) => 0.23,
      wristHalf: (d) => 0.25,
      props: (f) => _barbell(f.wrist.dy, half: 0.30),
    ),
    _frontOfSide(
      side('standing_calf_raise'),
      ankleHalf: 0.12,
      armsProjected: true,
      elbowHalf: (d) => 0.23,
      wristHalf: (d) => 0.23,
    ),
  ];
  return {for (final d in defs) d.id: d};
}

MotionDef _frontOfSide(
  MotionDef source, {
  required double ankleHalf,
  required double Function(double d) wristHalf,
  double Function(double d)? elbowHalf,
  bool armsProjected = false,
  bool gripAtShoulder = false,
  Offset elbowPole = const Offset(0.5, -1),
  List<Prop> Function(Pose front)? props,
}) {
  const hipHalf = 0.11;
  const shoulderHalf = 0.20;
  return MotionDef(
    id: source.id,
    title: source.title,
    cue: source.cue,
    firstHalf: source.firstHalf,
    isometric: source.isometric,
    cyclic: source.cyclic,
    cycleSeconds: source.cycleSeconds,
    note: source.note,
    view: MotionView.front,
    viewLabel: 'Front view',
    projectedFrom: source.id,
    pose: (d) {
      final sp = source.pose(d);
      final ankleY = sp.ankle.dy;

      // Knees track over the feet: a little outside the ankle, never so far
      // that a leg would have to stretch.
      final room = math.min(
        math.sqrt(
          math.max(0.0, kShin * kShin - math.pow(sp.knee.dy - ankleY, 2)),
        ),
        math.sqrt(
          math.max(0.0, kThigh * kThigh - math.pow(sp.hip.dy - sp.knee.dy, 2)),
        ),
      );
      final kneeR = Offset(ankleHalf + math.min(0.03, room), sp.knee.dy);

      final handY = gripAtShoulder ? sp.shoulder.dy + 0.03 : sp.wrist.dy;
      // Hands can only be as wide as the arms reach: at a straight-arm
      // lockout they are directly over the shoulders.
      var wh = wristHalf(d);
      if (!armsProjected) {
        final dy = handY - sp.shoulder.dy;
        final reach = (kUpperArm + kForeArm) * 0.995;
        wh = math.min(
          wh,
          shoulderHalf + math.sqrt(math.max(0.0, reach * reach - dy * dy)),
        );
      }
      final wristR = Offset(wh, handY);
      Offset elbowR;
      var err = 0.0;
      if (armsProjected) {
        elbowR = Offset(elbowHalf!(d), sp.elbow.dy);
      } else {
        final c = twoBone(
          Offset(shoulderHalf, sp.shoulder.dy),
          wristR,
          kUpperArm,
          kForeArm,
          elbowPole,
        );
        elbowR = c.mid;
        err = c.error;
      }
      Offset mx(Offset o) => Offset(-o.dx, o.dy);

      final ankleR = Offset(ankleHalf, ankleY);
      final heelR = Offset(ankleHalf, sp.heel.dy);
      final toeR = Offset(ankleHalf + 0.10, sp.toe.dy);

      final front = Pose(
        hip: Offset(hipHalf, sp.hip.dy),
        knee: kneeR,
        ankle: ankleR,
        heel: heelR,
        toe: toeR,
        shoulder: Offset(shoulderHalf, sp.shoulder.dy),
        elbow: elbowR,
        wrist: wristR,
        head: Offset(0, sp.head.dy),
        focus: wristR,
        farKnee: mx(kneeR),
        farAnkle: mx(ankleR),
        farHeel: mx(heelR),
        farToe: mx(toeR),
        farElbow: mx(elbowR),
        farWrist: mx(wristR),
        farShoulder: Offset(-shoulderHalf, sp.shoulder.dy),
        farHip: Offset(-hipHalf, sp.hip.dy),
        reachError: err,
      );
      return props == null ? front : front.withProps(props(front));
    },
  );
}
