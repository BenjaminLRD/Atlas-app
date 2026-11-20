import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/exercise/exercise_motion.dart';

/// The world-space rectangle that holds every pose of a demonstration, so the
/// figure keeps one scale for the whole loop.
Rect motionBounds(MotionDef motion) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  void add(Offset? o) {
    if (o == null) return;
    minX = math.min(minX, o.dx);
    maxX = math.max(maxX, o.dx);
    minY = math.min(minY, o.dy);
    maxY = math.max(maxY, o.dy);
  }

  for (var i = 0; i <= 32; i++) {
    final pose = motion.poseAt(i / 32);
    for (final o in [
      pose.hip,
      pose.knee,
      pose.ankle,
      pose.heel,
      pose.toe,
      pose.shoulder,
      pose.elbow,
      pose.wrist,
      pose.head,
      pose.farKnee,
      pose.farAnkle,
      pose.farElbow,
      pose.farWrist,
      pose.farShoulder,
      pose.farHip,
    ]) {
      add(o);
    }
    for (final p in pose.props) {
      if (p.kind == PropKind.circle) {
        add(p.a + Offset(p.radius, p.radius));
        add(p.a - Offset(p.radius, p.radius));
      } else {
        add(p.a);
        add(p.b);
      }
    }
  }
  add(const Offset(0, 0));
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Draws one frame of a demonstration.
class MotionPainter extends CustomPainter {
  final MotionDef motion;
  final double t;
  final Rect bounds;
  final Color bodyColor;
  final Color propColor;
  final Color groundColor;
  final Color eccentricColor;

  MotionPainter({
    required this.motion,
    required this.t,
    required this.bounds,
    this.bodyColor = AppColors.primary,
    this.propColor = const Color(0xFF8A949C),
    this.groundColor = const Color(0xFF3A444C),
    this.eccentricColor = const Color(0xFFF59E0B),
  });

  late double _scale;
  late Offset _origin;

  Offset _p(Offset w) =>
      Offset(_origin.dx + w.dx * _scale, _origin.dy - w.dy * _scale);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 22.0;
    final w = math.max(bounds.width, 0.5);
    final h = math.max(bounds.height, 0.5);
    _scale = math.min(
      (size.width - 2 * pad) / w,
      (size.height - 2 * pad - 18) / h,
    );
    final cx = size.width / 2 - (bounds.left + w / 2) * _scale;
    final cy = size.height / 2 - 4 + (bounds.top + h / 2) * _scale;
    _origin = Offset(cx, cy);

    final state = motion.at(t);
    final pose = motion.pose(state.d);

    // Ground. A figure that travels stays in the middle and the marks slide
    // past, so planted feet visibly stay put.
    final g = Paint()
      ..color = groundColor
      ..strokeWidth = 2;
    if (motion.view != MotionView.top) {
      canvas.drawLine(
        Offset(8, _p(const Offset(0, 0)).dy),
        Offset(size.width - 8, _p(const Offset(0, 0)).dy),
        g,
      );
      final per = motion.travelPerCycle;
      if (per != null) {
        final spacing = per / 5;
        final first = (pose.travel / spacing).floor() - 12;
        for (var i = first; i < first + 30; i++) {
          final x = _p(Offset(i * spacing - pose.travel, 0)).dx;
          if (x < 8 || x > size.width - 8) continue;
          canvas.drawLine(
            Offset(x, _p(const Offset(0, 0)).dy),
            Offset(x, _p(const Offset(0, 0)).dy + 6),
            g,
          );
        }
      }
    }

    // Props.
    final prop = Paint()
      ..color = propColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, 0.025 * _scale)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = propColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final pr in pose.props) {
      switch (pr.kind) {
        case PropKind.line:
          if (pr.dashed) {
            _dashed(canvas, _p(pr.a), _p(pr.b), prop);
          } else {
            canvas.drawLine(_p(pr.a), _p(pr.b), prop);
          }
        case PropKind.circle:
          canvas.drawCircle(
            _p(pr.a),
            pr.radius * _scale,
            pr.filled ? fill : prop,
          );
          if (pr.filled) {
            canvas.drawCircle(_p(pr.a), pr.radius * _scale, prop);
          }
        case PropKind.rect:
          final r = Rect.fromPoints(_p(pr.a), _p(pr.b));
          canvas.drawRect(r, fill);
          canvas.drawRect(r, prop);
      }
    }

    final limb = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055 * _scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (motion.view != MotionView.side) {
      _paintFrontBody(canvas, pose, limb);
      _arrow(canvas, pose, state);
      return;
    }
    final dim = Paint()
      ..color = bodyColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * _scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Far limbs behind.
    if (pose.farAnkle != null && pose.farKnee != null) {
      final path = Path()
        ..moveTo(_p(pose.hip).dx, _p(pose.hip).dy)
        ..lineTo(_p(pose.farKnee!).dx, _p(pose.farKnee!).dy)
        ..lineTo(_p(pose.farAnkle!).dx, _p(pose.farAnkle!).dy);
      canvas.drawPath(path, dim);
      if (pose.farHeel != null && pose.farToe != null) {
        final foot = Path()
          ..moveTo(_p(pose.farHeel!).dx, _p(pose.farHeel!).dy)
          ..lineTo(_p(pose.farAnkle!).dx, _p(pose.farAnkle!).dy)
          ..lineTo(_p(pose.farToe!).dx, _p(pose.farToe!).dy);
        canvas.drawPath(foot, dim);
      }
    }
    if (pose.farElbow != null && pose.farWrist != null) {
      final arm = Path()
        ..moveTo(_p(pose.shoulder).dx, _p(pose.shoulder).dy)
        ..lineTo(_p(pose.farElbow!).dx, _p(pose.farElbow!).dy)
        ..lineTo(_p(pose.farWrist!).dx, _p(pose.farWrist!).dy);
      canvas.drawPath(arm, dim);
    }

    // Trunk (or a curved spine).
    if (pose.spine != null) {
      final s = Path()
        ..moveTo(_p(pose.spine!.first).dx, _p(pose.spine!.first).dy);
      for (final o in pose.spine!.skip(1)) {
        s.lineTo(_p(o).dx, _p(o).dy);
      }
      canvas.drawPath(s, limb..strokeWidth = 0.075 * _scale);
      limb.strokeWidth = 0.055 * _scale;
    } else {
      canvas.drawLine(
        _p(pose.hip),
        _p(pose.shoulder),
        limb..strokeWidth = 0.075 * _scale,
      );
      limb.strokeWidth = 0.055 * _scale;
    }

    // Near leg and foot.
    final leg = Path()
      ..moveTo(_p(pose.hip).dx, _p(pose.hip).dy)
      ..lineTo(_p(pose.knee).dx, _p(pose.knee).dy)
      ..lineTo(_p(pose.ankle).dx, _p(pose.ankle).dy);
    canvas.drawPath(leg, limb);
    final foot = Path()
      ..moveTo(_p(pose.heel).dx, _p(pose.heel).dy)
      ..lineTo(_p(pose.ankle).dx, _p(pose.ankle).dy)
      ..lineTo(_p(pose.toe).dx, _p(pose.toe).dy);
    canvas.drawPath(foot, limb..strokeWidth = 0.04 * _scale);
    limb.strokeWidth = 0.055 * _scale;

    // Near arm.
    final armPath = Path()
      ..moveTo(_p(pose.shoulder).dx, _p(pose.shoulder).dy)
      ..lineTo(_p(pose.elbow).dx, _p(pose.elbow).dy)
      ..lineTo(_p(pose.wrist).dx, _p(pose.wrist).dy);
    canvas.drawPath(armPath, limb);

    // Joints and head.
    final joint = Paint()..color = Colors.white;
    for (final j in [pose.knee, pose.elbow, pose.hip, pose.shoulder]) {
      canvas.drawCircle(_p(j), 0.022 * _scale + 1.2, joint);
    }
    canvas.drawCircle(
      _p(pose.head),
      0.095 * _scale,
      Paint()..color = bodyColor,
    );

    _arrow(canvas, pose, state);
  }

  void _arrow(Canvas canvas, Pose pose, ({double d, MotionPhase phase}) state) {
    if (state.phase == MotionPhase.eccentric ||
        state.phase == MotionPhase.concentric) {
      final next = motion.pose(math.min(1.0, state.d + 0.04)).focus;
      final prev = motion.pose(math.max(0.0, state.d - 0.04)).focus;
      var dir = state.phase == MotionPhase.eccentric
          ? (motion.firstHalf == MotionPhase.eccentric
                ? next - prev
                : prev - next)
          : (motion.firstHalf == MotionPhase.concentric
                ? next - prev
                : prev - next);
      if (dir.distance > 1e-4) {
        dir = dir / dir.distance;
        // World y is up; screen y is down.
        final screen = Offset(dir.dx, -dir.dy);
        final from = _p(pose.focus) + screen * 22;
        final to = from + screen * 30;
        final color = state.phase == MotionPhase.eccentric
            ? eccentricColor
            : bodyColor;
        final a = Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, a);
        final left = Offset(
          screen.dx * math.cos(2.6) - screen.dy * math.sin(2.6),
          screen.dx * math.sin(2.6) + screen.dy * math.cos(2.6),
        );
        final right = Offset(
          screen.dx * math.cos(-2.6) - screen.dy * math.sin(-2.6),
          screen.dx * math.sin(-2.6) + screen.dy * math.cos(-2.6),
        );
        canvas.drawLine(to, to + left * 9, a);
        canvas.drawLine(to, to + right * 9, a);
      }
    }
  }

  void _paintFrontBody(Canvas canvas, Pose pose, Paint limb) {
    final top = motion.view == MotionView.top;
    final dim = Paint()
      ..color = bodyColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * _scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(Offset a, Offset b, Paint p) => canvas.drawLine(_p(a), _p(b), p);
    void chain(List<Offset> pts, Paint p) {
      final path = Path()..moveTo(_p(pts.first).dx, _p(pts.first).dy);
      for (final o in pts.skip(1)) {
        path.lineTo(_p(o).dx, _p(o).dy);
      }
      canvas.drawPath(path, p);
    }

    final sR = pose.shoulder;
    final sL = pose.farShoulder ?? Offset(-pose.shoulder.dx, pose.shoulder.dy);
    final hR = pose.hip;
    final hL = pose.farHip ?? Offset(-pose.hip.dx, pose.hip.dy);
    final trunk = limb..strokeWidth = 0.075 * _scale;

    if (!top) {
      // Legs.
      chain([hR, pose.knee, pose.ankle], limb);
      chain([hL, pose.farKnee ?? hL, pose.farAnkle ?? hL], dim);
      if (pose.farAnkle != null && pose.farToe != null) {
        line(pose.farAnkle!, pose.farToe!, dim);
      }
      line(pose.ankle, pose.toe, limb);
    }
    // Torso: shoulders, pelvis and the sides between them.
    line(sL, sR, trunk);
    line(hL, hR, trunk);
    line(sL, hL, trunk..strokeWidth = 0.05 * _scale);
    line(sR, hR, trunk);
    limb.strokeWidth = 0.055 * _scale;

    // Arms.
    chain([sR, pose.elbow, pose.wrist], limb);
    if (pose.farElbow != null && pose.farWrist != null) {
      chain([sL, pose.farElbow!, pose.farWrist!], dim);
    }

    final joint = Paint()..color = Colors.white;
    for (final j in [pose.elbow, pose.farElbow, sR, sL]) {
      if (j != null) canvas.drawCircle(_p(j), 0.022 * _scale + 1.2, joint);
    }
    canvas.drawCircle(
      _p(pose.head),
      0.095 * _scale,
      Paint()..color = bodyColor,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 10) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 5, total), paint);
    }
  }

  @override
  bool shouldRepaint(MotionPainter old) => old.t != t || old.motion != motion;
}

String phaseLabel(MotionPhase p) => switch (p) {
  MotionPhase.eccentric => 'LOWERING  ·  ECCENTRIC',
  MotionPhase.concentric => 'LIFTING  ·  CONCENTRIC',
  MotionPhase.hold => 'HOLD',
  MotionPhase.cycle => 'CONTINUOUS MOVEMENT',
};

/// A looping demonstration of one exercise with its name and the current
/// phase of the movement.
class ExerciseMotionView extends StatefulWidget {
  final MotionDef motion;
  final bool showCue;
  final bool animate;

  /// Freeze at a point of the loop (tests, reduced motion).
  final double? fixedT;

  const ExerciseMotionView({
    super.key,
    required this.motion,
    this.showCue = false,
    this.animate = true,
    this.fixedT,
  });

  @override
  State<ExerciseMotionView> createState() => _ExerciseMotionViewState();
}

class _ExerciseMotionViewState extends State<ExerciseMotionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Rect _bounds;

  @override
  void initState() {
    super.initState();
    _bounds = motionBounds(widget.motion);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.motion.cycleSeconds * 1000).round(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // People who turn animations off in system settings get a still pose.
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldRun = widget.animate && widget.fixedT == null && !still;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun) {
      _controller.stop();
      _controller.value = 0.3;
    }
  }

  @override
  void didUpdateWidget(ExerciseMotionView old) {
    super.didUpdateWidget(old);
    // The side and front views of one exercise share an id, so compare the
    // view too. The controller is kept, so switching views continues the
    // same repetition instead of restarting it.
    if (old.motion.id != widget.motion.id ||
        old.motion.view != widget.motion.view) {
      _bounds = motionBounds(widget.motion);
      _controller.duration = Duration(
        milliseconds: (widget.motion.cycleSeconds * 1000).round(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.fixedT ?? _controller.value;
        final state = widget.motion.at(t);
        final color = switch (state.phase) {
          MotionPhase.eccentric => const Color(0xFFF59E0B),
          MotionPhase.concentric => AppColors.primary,
          _ => Colors.white70,
        };
        return Container(
          key: Key('motion_${widget.motion.id}'),
          color: const Color(0xFF0F1417),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: MotionPainter(
                  motion: widget.motion,
                  t: t,
                  bounds: _bounds,
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        phaseLabel(state.phase),
                        key: const Key('motion_phase'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        widget.motion.note == null
                            ? widget.motion.viewLabel
                            : '${widget.motion.viewLabel} · ${widget.motion.note}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
