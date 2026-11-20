import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:atlas/services/exercise/exercise_motion.dart';

typedef ThumbDecor =
    void Function(Canvas canvas, Offset Function(Offset world) p, double s);

/// Draws one exercise as a static illustration: a green humanoid figure on
/// Atlas's charcoal background, in the pose and from the viewpoint that make
/// the exercise recognisable. Every thumbnail goes through this one painter,
/// so every figure has the same proportions, shading and palette.
///
/// This is a development tool: it renders the PNG files shipped under
/// assets/exercises. Nothing here runs when the app is open.
class FigurePainter {
  // Atlas palette.
  static const bgTop = Color(0xFF1C2226);
  static const bgBottom = Color(0xFF0E1214);
  static const emerald = Color(0xFF10B981);

  // Green skin, lit from the upper left.
  static const skinLight = Color(0xFF6EE0A4);
  static const skinMid = Color(0xFF34B873);
  static const skinDark = Color(0xFF1B7A4C);
  static const farLight = Color(0xFF2A9B63);
  static const farMid = Color(0xFF1F7C4F);
  static const farDark = Color(0xFF145A39);
  static const muscleLine = Color(0xFF1E8A57);

  static const steel = Color(0xFFC3CBD2);
  static const steelDark = Color(0xFF7D8890);
  static const iron = Color(0xFF2B3238);
  static const ironEdge = Color(0xFF55616A);
  static const pad = Color(0xFF3A444C);

  final MotionDef motion;
  final Pose pose;
  final Size size;
  final List<Prop> extraProps;

  /// Extra drawing for equipment that has no Prop shape (a ball, water, a
  /// door frame). Each callback gets the canvas, the world-to-canvas mapping
  /// and the metres-to-pixels scale; [behind] runs before the body, [front]
  /// after it.
  final List<ThumbDecor> behind;
  final List<ThumbDecor> front;
  final bool floor;

  /// Points that must stay inside the picture although nothing is a Prop
  /// there (the far edge of a ball, say).
  final List<Offset> fitPoints;

  /// Draw a weight-stack tower at every cable pulley.
  final bool towers;

  late final double _s;
  late final Offset _o;

  FigurePainter({
    required this.motion,
    required this.pose,
    required this.size,
    this.extraProps = const [],
    this.behind = const [],
    this.front = const [],
    this.floor = true,
    this.fitPoints = const [],
    this.towers = true,
  }) {
    _fit();
  }

  // ---------------------------------------------------------------- layout

  List<Offset> _points() => [
    pose.hip,
    pose.knee,
    pose.ankle,
    pose.heel,
    pose.toe,
    pose.shoulder,
    pose.elbow,
    pose.wrist,
    pose.head + const Offset(0, 0.10),
    ?pose.farKnee,
    ?pose.farAnkle,
    ?pose.farElbow,
    ?pose.farWrist,
    ?pose.farShoulder,
    ?pose.farHip,
    ...?pose.spine,
  ];

  void _fit() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    void add(Offset o) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }

    for (final o in [..._points(), ...fitPoints]) {
      add(o);
    }
    for (final p in [...pose.props, ...extraProps]) {
      if (p.kind == PropKind.circle) {
        add(p.a + Offset(p.radius, p.radius));
        add(p.a - Offset(p.radius, p.radius));
      } else {
        add(p.a);
        add(p.b);
      }
    }
    if (motion.view != MotionView.top) {
      for (final pu
          in towers ? _pulleys([...pose.props, ...extraProps]) : <Offset>[]) {
        add(Offset(pu.dx - 0.10, minY));
        add(Offset(pu.dx + 0.10, maxY));
      }
      add(Offset(minX, 0));
    }
    // Room for limb thickness and a little air around the whole picture.
    final w = (maxX - minX) + 0.30;
    final h = (maxY - minY) + 0.30;
    final fit = math.min(size.width * 0.88 / w, size.height * 0.88 / h);
    // A standing adult is 1.75 m: never draw a small movement bigger than the
    // largest framing a standing figure would get, so the catalogue keeps one
    // consistent figure size.
    final cap = size.height * 0.80 / 1.95;
    _s = math.min(fit, cap * 1.18);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    _o = Offset(
      size.width / 2 - cx * _s,
      size.height / 2 + cy * _s + size.height * 0.015,
    );
  }

  Offset _p(Offset w) => Offset(_o.dx + w.dx * _s, _o.dy - w.dy * _s);

  // ----------------------------------------------------------------- paint

  void paint(Canvas canvas) {
    _background(canvas);
    final top = motion.view == MotionView.top;
    if (!top && floor) _floor(canvas);
    for (final d in behind) {
      d(canvas, _p, _s);
    }
    final all = [...pose.props, ...extraProps];
    // Equipment behind the body first (benches, pads, frames), then the body,
    // then the equipment the hands hold.
    if (!top && towers) _cableTowers(canvas, all);
    _props(canvas, all.where((p) => p.kind == PropKind.rect));
    if (motion.view == MotionView.side) {
      _sideBody(canvas);
    } else {
      _frontBody(canvas, top: top);
    }
    _props(canvas, all.where((p) => p.kind != PropKind.rect));
    for (final d in front) {
      d(canvas, _p, _s);
    }
  }

  /// Pulleys in the pose: the small open circles, or failing that the far end
  /// of each cable line.
  List<Offset> _pulleys(List<Prop> props) {
    final out = <Offset>[];
    for (final pr in props) {
      if (pr.kind == PropKind.circle && !pr.filled && pr.radius < 0.08) {
        out.add(pr.a);
      }
    }
    if (out.isNotEmpty) return out;
    final hands = [pose.wrist, ?pose.farWrist];
    double dist(Offset o) =>
        hands.map((h) => (h - o).distance).reduce(math.min);
    for (final pr in props) {
      if (pr.kind == PropKind.line && pr.dashed) {
        out.add(dist(pr.a) > dist(pr.b) ? pr.a : pr.b);
      }
    }
    return out;
  }

  /// Every cable runs to a pulley on a weight-stack tower; draw the tower so a
  /// cable exercise shows its machine.
  void _cableTowers(Canvas c, List<Prop> props) {
    final done = <double>{};
    for (final pulley in _pulleys(props)) {
      final key = (pulley.dx * 100).roundToDouble();
      if (!done.add(key)) continue;
      final top = math.max(1.95, pulley.dy + 0.18);
      final col = Rect.fromPoints(
        _p(Offset(pulley.dx - 0.10, 0)),
        _p(Offset(pulley.dx + 0.10, top)),
      );
      final rr = RRect.fromRectAndRadius(col, const Radius.circular(8));
      c.drawRRect(rr, Paint()..color = const Color(0xFF262D33));
      c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ironEdge
          ..strokeWidth = 1.6,
      );
      // The weight stack: stacked plates inside the column.
      const stackTop = 1.15, stackBottom = 0.12;
      for (var y = stackBottom; y < stackTop; y += 0.075) {
        final r = Rect.fromPoints(
          _p(Offset(pulley.dx - 0.075, y + 0.065)),
          _p(Offset(pulley.dx + 0.075, y)),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)),
          Paint()..color = const Color(0xFF3C464E),
        );
      }
      c.drawCircle(
        _p(pulley),
        0.045 * _s,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = steel
          ..strokeWidth = math.max(2.2, 0.014 * _s),
      );
    }
  }

  void _background(Canvas canvas) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          bgTop,
          bgBottom,
        ]),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.55),
          size.width * 0.62,
          [emerald.withValues(alpha: 0.26), emerald.withValues(alpha: 0)],
        ),
    );
  }

  void _floor(Canvas canvas) {
    final y = _p(Offset.zero).dy;
    canvas.drawLine(
      Offset(size.width * 0.07, y),
      Offset(size.width * 0.93, y),
      Paint()
        ..color = const Color(0xFF3A444C)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    // Soft contact shadow under the figure.
    final c = _p(Offset((pose.ankle.dx + pose.hip.dx) / 2, 0));
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, 3),
        width: _s * 0.9,
        height: _s * 0.07,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // ------------------------------------------------------------ primitives

  Paint _skin(Offset a, Offset b, double r, {bool far = false}) {
    final mid = (a + b) / 2;
    final d = b - a;
    var n = d.distance < 1e-6
        ? const Offset(-0.7, -0.7)
        : Offset(-d.dy, d.dx) / d.distance;
    // Light comes from above and to the left.
    if (n.dy > 0 || (n.dy == 0 && n.dx > 0)) n = -n;
    final colors = far
        ? [farLight, farMid, farDark]
        : [skinLight, skinMid, skinDark];
    return Paint()
      ..shader = ui.Gradient.linear(mid + n * r, mid - n * r, colors, const [
        0.0,
        0.45,
        1.0,
      ]);
  }

  /// A tapered limb segment between two joints, radii in metres.
  void _limb(
    Canvas c,
    Offset wa,
    Offset wb,
    double ra,
    double rb, {
    bool far = false,
  }) {
    final a = _p(wa), b = _p(wb);
    final pa = ra * _s, pb = rb * _s;
    final paint = _skin(a, b, math.max(pa, pb), far: far);
    c.drawCircle(a, pa, paint);
    c.drawCircle(b, pb, paint);
    final d = b - a;
    if (d.distance > 1e-3) {
      final v = Offset(-d.dy, d.dx) / d.distance;
      final path = Path()
        ..moveTo(a.dx + v.dx * pa, a.dy + v.dy * pa)
        ..lineTo(b.dx + v.dx * pb, b.dy + v.dy * pb)
        ..lineTo(b.dx - v.dx * pb, b.dy - v.dy * pb)
        ..lineTo(a.dx - v.dx * pa, a.dy - v.dy * pa)
        ..close();
      c.drawPath(path, paint);
    }
  }

  void _joint(Canvas c, Offset w, double r, {bool far = false}) {
    c.drawCircle(
      _p(w),
      r * _s,
      Paint()..color = (far ? farDark : skinDark).withValues(alpha: 0.55),
    );
  }

  void _hand(Canvas c, Offset w, {bool far = false}) {
    c.drawCircle(_p(w), 0.036 * _s, _skin(w, w, 0.036 * _s, far: far));
  }

  void _head(Canvas c, Offset center, double tilt) {
    final p = _p(center);
    final r = 0.098 * _s;
    c.drawCircle(p, r, _skin(p.translate(0, -r), p.translate(0, r), r));
    // A soft highlight on the crown keeps the head from looking flat.
    c.drawCircle(
      p.translate(-r * 0.3, -r * 0.35),
      r * 0.32,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
  }

  // ------------------------------------------------------------- side body

  void _sideBody(Canvas c) {
    // Far limbs, darker, behind the trunk.
    if (pose.farKnee != null && pose.farAnkle != null) {
      _limb(c, pose.hip, pose.farKnee!, 0.078, 0.052, far: true);
      _limb(c, pose.farKnee!, pose.farAnkle!, 0.050, 0.036, far: true);
      if (pose.farHeel != null && pose.farToe != null) {
        _limb(c, pose.farHeel!, pose.farToe!, 0.030, 0.026, far: true);
      }
    }
    if (pose.farElbow != null && pose.farWrist != null) {
      _limb(c, pose.shoulder, pose.farElbow!, 0.047, 0.038, far: true);
      _limb(c, pose.farElbow!, pose.farWrist!, 0.038, 0.030, far: true);
      _hand(c, pose.farWrist!, far: true);
    }

    // Trunk.
    if (pose.spine != null && pose.spine!.length > 1) {
      final s = pose.spine!;
      for (var i = 0; i < s.length - 1; i++) {
        final t0 = i / (s.length - 1), t1 = (i + 1) / (s.length - 1);
        _limb(c, s[i], s[i + 1], 0.098 + 0.02 * t0, 0.098 + 0.02 * t1);
      }
    } else {
      _limb(c, pose.hip, pose.shoulder, 0.100, 0.112);
    }
    // Neck and head.
    _limb(c, pose.shoulder, pose.head, 0.040, 0.036);
    _head(c, pose.head, 0);

    // Near leg.
    _limb(c, pose.hip, pose.knee, 0.082, 0.056);
    _limb(c, pose.knee, pose.ankle, 0.054, 0.038);
    _limb(c, pose.heel, pose.toe, 0.032, 0.028);
    _joint(c, pose.knee, 0.030);

    // Near arm (in front of the trunk).
    _limb(c, pose.shoulder, pose.elbow, 0.050, 0.040);
    _limb(c, pose.elbow, pose.wrist, 0.040, 0.031);
    _joint(c, pose.elbow, 0.024);
    _hand(c, pose.wrist);
  }

  // ------------------------------------------------------------ front body

  void _frontBody(Canvas c, {required bool top}) {
    final sR = pose.shoulder;
    final sL = pose.farShoulder ?? Offset(-sR.dx, sR.dy);
    final hR = pose.hip;
    final hL = pose.farHip ?? Offset(-hR.dx, hR.dy);

    if (!top) {
      // Legs: left (dim) then right.
      if (pose.farKnee != null && pose.farAnkle != null) {
        _limb(c, hL, pose.farKnee!, 0.080, 0.054, far: true);
        _limb(c, pose.farKnee!, pose.farAnkle!, 0.052, 0.036, far: true);
        if (pose.farToe != null) {
          _limb(c, pose.farAnkle!, pose.farToe!, 0.030, 0.026, far: true);
        }
      }
      _limb(c, hR, pose.knee, 0.082, 0.056);
      _limb(c, pose.knee, pose.ankle, 0.054, 0.038);
      _limb(c, pose.ankle, pose.toe, 0.030, 0.026);
    }

    // Torso: a tapered block from the shoulder line to the pelvis.
    final tl = _p(sL + const Offset(-0.035, 0.03));
    final tr = _p(sR + const Offset(0.035, 0.03));
    final wr = _p(Offset(hR.dx + 0.045, (hR.dy + sR.dy) / 2 - 0.02));
    final wl = _p(Offset(hL.dx - 0.045, (hL.dy + sL.dy) / 2 - 0.02));
    final br = _p(hR + const Offset(0.06, -0.02));
    final bl = _p(hL + const Offset(-0.06, -0.02));
    final torso = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(wr.dx, wr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..lineTo(wl.dx, wl.dy)
      ..close();
    final tmid = _p(Offset(0, (sR.dy + hR.dy) / 2));
    c.drawPath(
      torso,
      Paint()
        ..shader = ui.Gradient.linear(
          tmid.translate(-_s * 0.25, -_s * 0.1),
          tmid.translate(_s * 0.25, _s * 0.1),
          const [skinLight, skinMid, skinDark],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Muscle detail: a centre line and the lower edge of the chest.
    final line = Paint()
      ..color = muscleLine
      ..strokeWidth = math.max(1.4, 0.008 * _s)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final topMid = _p(Offset(0, sR.dy - 0.04));
    final botMid = _p(Offset(0, hR.dy + 0.02));
    c.drawLine(topMid, botMid, line);
    final pecY = sR.dy - 0.16;
    if (pecY > hR.dy + 0.1) {
      final pl = _p(Offset(-0.15, pecY)), pr = _p(Offset(0.15, pecY));
      final cm = _p(Offset(0, pecY - 0.03));
      c.drawPath(
        Path()
          ..moveTo(pl.dx, pl.dy)
          ..quadraticBezierTo(cm.dx, cm.dy + 6, pr.dx, pr.dy),
        line,
      );
    }
    // Shoulder caps.
    for (final s in [sR, sL]) {
      c.drawCircle(_p(s), 0.062 * _s, _skin(_p(s), _p(s), 0.062 * _s));
    }

    // Neck and head.
    _limb(c, Offset(0, sR.dy), pose.head, 0.045, 0.040);
    _head(c, pose.head, 0);

    // Arms.
    if (pose.farElbow != null && pose.farWrist != null) {
      _limb(c, sL, pose.farElbow!, 0.047, 0.038, far: true);
      _limb(c, pose.farElbow!, pose.farWrist!, 0.038, 0.030, far: true);
      _hand(c, pose.farWrist!, far: true);
    }
    _limb(c, sR, pose.elbow, 0.050, 0.040);
    _limb(c, pose.elbow, pose.wrist, 0.040, 0.031);
    _hand(c, pose.wrist);
  }

  // ----------------------------------------------------------------- props

  void _props(Canvas c, Iterable<Prop> props) {
    final bar = Paint()
      ..color = steel
      ..strokeWidth = math.max(2.5, 0.020 * _s)
      ..strokeCap = StrokeCap.round;
    for (final pr in props) {
      switch (pr.kind) {
        case PropKind.line:
          final a = _p(pr.a), b = _p(pr.b);
          if (pr.dashed) {
            // Cables and ropes: thin, light.
            c.drawLine(
              a,
              b,
              Paint()
                ..color = const Color(0xFFD7DDE2).withValues(alpha: 0.85)
                ..strokeWidth = math.max(1.6, 0.010 * _s)
                ..strokeCap = StrokeCap.round,
            );
          } else {
            c.drawLine(a, b, bar);
          }
        case PropKind.circle:
          final p = _p(pr.a);
          // Small filled circles are dumbbell heads: draw them big enough to
          // read at thumbnail size.
          final r = pr.radius * _s * (pr.filled && pr.radius < 0.08 ? 1.55 : 1);
          if (pr.filled) {
            // A weight plate or dumbbell head: dark disc, bright rim, hub.
            c.drawCircle(p, r, Paint()..color = iron);
            c.drawCircle(
              p,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = ironEdge
                ..strokeWidth = math.max(1.6, r * 0.10),
            );
            c.drawCircle(p, r * 0.22, Paint()..color = steel);
          } else {
            c.drawCircle(
              p,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = steelDark
                ..strokeWidth = math.max(2, 0.012 * _s),
            );
          }
        case PropKind.rect:
          final rect = Rect.fromPoints(_p(pr.a), _p(pr.b));
          final rr = RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(rect.shortestSide * 0.35, 8)),
          );
          c.drawRRect(rr, Paint()..color = pad);
          c.drawRRect(
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = ironEdge
              ..strokeWidth = 1.6,
          );
      }
    }
  }
}
