import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/exercise/muscle_map.dart';

/// Geometry of the body figure, in a 200 x 440 box. Everything is vector code
/// bundled with the app, so the figure works offline and costs no download.
/// Each region is drawn for the right half and mirrored, which also keeps the
/// two sides identical (unilateral work is not distinguished left from right).
class MuscleBodyGeometry {
  const MuscleBodyGeometry._();

  static const double width = 200;
  static const double height = 440;

  static const _skin = {
    'arm': [
      Offset(150, 84), Offset(164, 92), Offset(170, 112), Offset(170, 140),
      Offset(168, 164), Offset(172, 192), Offset(176, 224), Offset(180, 248),
      Offset(176, 264), Offset(166, 262), Offset(160, 240), Offset(156, 222),
      Offset(152, 192), Offset(149, 166), Offset(147, 140), Offset(145, 114),
      Offset(142, 98), //
    ],
  };

  static const List<Offset> _torsoRight = [
    Offset(110, 54), Offset(113, 66), Offset(134, 78), Offset(150, 86),
    Offset(146, 112), Offset(140, 128), Offset(137, 150), Offset(130, 185),
    Offset(126, 210), Offset(134, 238), Offset(141, 262), Offset(140, 300),
    Offset(135, 338), Offset(132, 356), Offset(135, 384), Offset(129, 412),
    Offset(128, 428), Offset(134, 437), Offset(112, 439), Offset(111, 424),
    Offset(108, 390), Offset(105, 352), Offset(103, 310), Offset(102, 272),
    Offset(100, 258), //
  ];

  static Offset _mirror(Offset o) => Offset(200 - o.dx, o.dy);

  /// A smooth closed curve through [points] (Catmull-Rom as Beziers).
  static Path smooth(List<Offset> points, {double tension = 0.5}) {
    final n = points.length;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = points[(i - 1 + n) % n];
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final p3 = points[(i + 2) % n];
      final t = tension / 3 * 2 / 2;
      final c1 = p1 + (p2 - p0) * t;
      final c2 = p2 - (p3 - p1) * t;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  static Path _both(List<Offset> right) {
    final path = Path()
      ..addPath(smooth(right), Offset.zero)
      ..addPath(smooth(right.map(_mirror).toList()), Offset.zero);
    return path;
  }

  static Path? _bodyPath;
  static Path? _armsPath;

  /// Torso, hips and legs as one outline.
  static Path get body {
    return _bodyPath ??= () {
      final left = _torsoRight.reversed.skip(1).map(_mirror);
      return smooth([..._torsoRight, ...left]);
    }();
  }

  static Path get arms {
    return _armsPath ??= _both(_skin['arm']!);
  }

  static Path get head => Path()
    ..addOval(const Rect.fromLTRB(84, 8, 116, 54))
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(92, 46, 108, 68),
        const Radius.circular(6),
      ),
    );

  static final Map<MuscleView, Map<MuscleRegion, Path>> _regions = {};

  static Map<MuscleRegion, Path> regionsFor(MuscleView view) {
    return _regions[view] ??= view == MuscleView.front ? _front() : _back();
  }

  static Map<MuscleRegion, Path> _front() => {
    MuscleRegion.traps: _both(const [
      Offset(112, 62), Offset(134, 77), Offset(149, 86), Offset(138, 92),
      Offset(120, 86), Offset(112, 74), //
    ]),
    MuscleRegion.chest: _both(const [
      Offset(103, 90),
      Offset(122, 88),
      Offset(140, 95),
      Offset(146, 108),
      Offset(140, 124),
      Offset(124, 134),
      Offset(110, 134),
      Offset(103, 124),
    ]),
    MuscleRegion.frontDelts: _both(const [
      Offset(143, 92), Offset(155, 90), Offset(161, 100), Offset(161, 118),
      Offset(154, 126), Offset(147, 116), Offset(143, 102), //
    ]),
    MuscleRegion.sideDelts: _both(const [
      Offset(159, 91), Offset(167, 97), Offset(170, 112), Offset(167, 128),
      Offset(162, 122), Offset(162, 102), //
    ]),
    MuscleRegion.biceps: _both(const [
      Offset(149, 130), Offset(160, 130), Offset(165, 148), Offset(163, 165),
      Offset(154, 167), Offset(149, 150), //
    ]),
    MuscleRegion.forearms: _both(const [
      Offset(151, 174), Offset(163, 172), Offset(171, 192), Offset(176, 224),
      Offset(168, 238), Offset(158, 222), Offset(153, 194), //
    ]),
    MuscleRegion.abs: Path()
      ..addPath(
        _both(const [
          Offset(102, 142),
          Offset(116, 143),
          Offset(117, 160),
          Offset(102, 162),
        ]),
        Offset.zero,
      )
      ..addPath(
        _both(const [
          Offset(102, 166),
          Offset(116, 166),
          Offset(116, 183),
          Offset(102, 185),
        ]),
        Offset.zero,
      )
      ..addPath(
        _both(const [
          Offset(102, 189),
          Offset(115, 189),
          Offset(114, 206),
          Offset(102, 207),
        ]),
        Offset.zero,
      ),
    MuscleRegion.obliques: _both(const [
      Offset(120, 142), Offset(134, 140), Offset(132, 170), Offset(127, 200),
      Offset(120, 205), Offset(119, 170), //
    ]),
    MuscleRegion.hipFlexors: _both(const [
      Offset(103, 212), Offset(120, 210), Offset(130, 226), Offset(124, 246),
      Offset(107, 252), Offset(102, 236), //
    ]),
    MuscleRegion.adductors: _both(const [
      Offset(102, 264), Offset(110, 262), Offset(112, 296), Offset(110, 326),
      Offset(104, 310), //
    ]),
    MuscleRegion.quads: _both(const [
      Offset(113, 258),
      Offset(126, 252),
      Offset(140, 264),
      Offset(139, 296),
      Offset(134, 332),
      Offset(124, 340),
      Offset(115, 330),
      Offset(113, 296),
    ]),
    MuscleRegion.calves: _both(const [
      Offset(122, 358), Offset(134, 366), Offset(135, 388), Offset(129, 410),
      Offset(122, 412), Offset(118, 388), //
    ]),
  };

  static Map<MuscleRegion, Path> _back() => {
    MuscleRegion.traps: _both(const [
      Offset(102, 62), Offset(112, 64), Offset(134, 78), Offset(150, 86),
      Offset(142, 100), Offset(122, 108), Offset(102, 116), //
    ]),
    MuscleRegion.rearDelts: _both(const [
      Offset(143, 91), Offset(156, 89), Offset(163, 98), Offset(161, 116),
      Offset(154, 124), Offset(147, 112), //
    ]),
    MuscleRegion.sideDelts: _both(const [
      Offset(159, 91), Offset(167, 97), Offset(170, 112), Offset(167, 128),
      Offset(162, 122), Offset(162, 102), //
    ]),
    MuscleRegion.triceps: _both(const [
      Offset(148, 128), Offset(160, 128), Offset(165, 148), Offset(162, 167),
      Offset(152, 167), Offset(148, 148), //
    ]),
    MuscleRegion.forearms: _both(const [
      Offset(151, 174), Offset(163, 172), Offset(171, 192), Offset(176, 224),
      Offset(168, 238), Offset(158, 222), Offset(153, 194), //
    ]),
    MuscleRegion.upperBack: _both(const [
      Offset(103, 119), Offset(122, 113), Offset(127, 124), Offset(122, 142),
      Offset(104, 153), //
    ]),
    MuscleRegion.lats: _both(const [
      Offset(125, 124), Offset(140, 114), Offset(141, 138), Offset(132, 180),
      Offset(124, 198), Offset(118, 176), Offset(122, 146), //
    ]),
    MuscleRegion.lowerBack: _both(const [
      Offset(103, 157), Offset(116, 159), Offset(121, 182), Offset(120, 206),
      Offset(103, 208), //
    ]),
    MuscleRegion.glutes: _both(const [
      Offset(102, 212), Offset(124, 208), Offset(138, 222), Offset(140, 244),
      Offset(128, 262), Offset(102, 262), //
    ]),
    MuscleRegion.hamstrings: _both(const [
      Offset(104, 268),
      Offset(126, 265),
      Offset(138, 275),
      Offset(137, 304),
      Offset(132, 336),
      Offset(122, 342),
      Offset(110, 332),
      Offset(104, 298),
    ]),
    MuscleRegion.calves: _both(const [
      Offset(108, 352), Offset(128, 352), Offset(135, 372), Offset(133, 392),
      Offset(125, 412), Offset(116, 412), Offset(108, 390), //
    ]),
  };
}

/// Colours of the figure. The figure always sits on its own dark panel, so it
/// reads the same in light and dark mode.
class MuscleBodyColors {
  const MuscleBodyColors._();

  static const Color panelTop = Color(0xFF1A1D24);
  static const Color panelBottom = Color(0xFF0D0F14);
  static const Color skinEdge = Color(0xFF262B33);
  static const Color skinCenter = Color(0xFF3B424C);
  static const Color regionFill = Color(0xFF444C58);
  static const Color regionLine = Color(0xFF5A6370);
  static const Color emerald = Color(0xFF32D74B);
  static const Color emeraldDeep = Color(0xFF0A8F3C);
}

/// Paints the body figure with the highlighted muscles.
class MuscleBodyPainter extends CustomPainter {
  final MuscleActivation activation;
  final MuscleView view;

  const MuscleBodyPainter({required this.activation, required this.view});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / MuscleBodyGeometry.width,
      size.height / MuscleBodyGeometry.height,
    );
    final dx = (size.width - MuscleBodyGeometry.width * scale) / 2;
    final dy = (size.height - MuscleBodyGeometry.height * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    const bounds = Rect.fromLTWH(
      0,
      0,
      MuscleBodyGeometry.width,
      MuscleBodyGeometry.height,
    );

    // Skin: a horizontal gradient (dark edge, lighter centre) gives the limbs
    // a rounded, lit-from-the-front look.
    final skin = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(52, 0),
        const Offset(148, 0),
        const [
          MuscleBodyColors.skinEdge,
          MuscleBodyColors.skinCenter,
          MuscleBodyColors.skinEdge,
        ],
        const [0, 0.5, 1],
      );
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);
    for (final part in [
      MuscleBodyGeometry.arms,
      MuscleBodyGeometry.body,
      MuscleBodyGeometry.head,
    ]) {
      canvas
        ..drawPath(part, skin)
        ..drawPath(part, rim);
    }

    final regions = MuscleBodyGeometry.regionsFor(view);
    final fill = Paint()..color = MuscleBodyColors.regionFill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = MuscleBodyColors.regionLine;
    final emeraldFill = Paint()
      ..shader = ui.Gradient.linear(
        bounds.topCenter,
        bounds.bottomCenter,
        const [MuscleBodyColors.emerald, MuscleBodyColors.emeraldDeep],
      );
    final glow = Paint()
      ..color = MuscleBodyColors.emerald.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Quiet regions first, then the highlighted ones on top so a glow is
    // never covered.
    for (final entry in regions.entries) {
      final role = activation.roleOf(entry.key);
      if (role == MuscleRole.none) {
        final tint = activation.general ? 0.30 : 0.0;
        canvas.drawPath(entry.value, fill);
        if (tint > 0) {
          canvas.drawPath(
            entry.value,
            Paint()..color = MuscleBodyColors.emerald.withValues(alpha: tint),
          );
        }
        canvas.drawPath(entry.value, line);
      }
    }
    for (final entry in regions.entries) {
      final role = activation.roleOf(entry.key);
      if (role == MuscleRole.secondary) {
        canvas
          ..drawPath(entry.value, fill)
          ..drawPath(
            entry.value,
            Paint()..color = MuscleBodyColors.emerald.withValues(alpha: 0.42),
          )
          ..drawPath(
            entry.value,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = MuscleBodyColors.emerald.withValues(alpha: 0.75),
          );
      }
    }
    for (final entry in regions.entries) {
      final role = activation.roleOf(entry.key);
      if (role == MuscleRole.primary) {
        canvas
          ..drawPath(entry.value, glow)
          ..drawPath(entry.value, emeraldFill)
          ..drawPath(
            entry.value,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Colors.white.withValues(alpha: 0.35),
          );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MuscleBodyPainter old) =>
      old.view != view ||
      old.activation.primary != activation.primary ||
      old.activation.secondary != activation.secondary ||
      old.activation.general != activation.general;
}
