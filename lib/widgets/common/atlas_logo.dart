import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// The Atlas AI mark: a circuit brain on the left, a vertical bar, and
/// barbell plates on the right. Drawn as vectors, so it stays sharp at any
/// size.
///
/// Used on the splash screen and in the AI coach. Below [_detailMinSize] the
/// circuit traces are dropped so the mark stays readable as an icon.
class AtlasLogoMark extends StatelessWidget {
  final double size;

  /// Adds a soft glow behind the mark. Keep it off for small uses.
  final bool glow;

  const AtlasLogoMark({super.key, this.size = 48, this.glow = false});

  static const double _detailMinSize = 28;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Atlas AI logo',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AtlasLogoPainter(
            glow: glow,
            detailed: size >= _detailMinSize,
          ),
        ),
      ),
    );
  }
}

/// "ATLAS AI" in the app's brand colors: ATLAS in the primary text color,
/// AI in the green accent.
class AtlasWordmark extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final TextAlign textAlign;

  const AtlasWordmark({
    super.key,
    this.fontSize = 32,
    this.letterSpacing = 2,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.headlineLg.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'ATLAS ',
            style: base.copyWith(color: context.appTextPrimary),
          ),
          TextSpan(
            text: 'AI',
            style: base.copyWith(color: AppColors.primaryContainer),
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: 1,
      semanticsLabel: 'Atlas AI',
    );
  }
}

class _AtlasLogoPainter extends CustomPainter {
  final bool glow;
  final bool detailed;

  const _AtlasLogoPainter({required this.glow, required this.detailed});

  // Design space is 100 x 100; the artwork spans x 4..84, so it is shifted
  // right by 8 to sit centred.
  static const double _shiftX = 8;

  static const Color _light = Color(0xFF4ADE80);
  static const Color _dark = Color(0xFF16A34A);

  // Brain outline: five rounded lobes closing against the divider bar.
  static Path _brain() => Path()
    ..moveTo(46, 22)
    ..cubicTo(44, 12, 30, 8, 24, 16)
    ..cubicTo(14, 14, 8, 26, 14, 34)
    ..cubicTo(4, 40, 6, 56, 14, 60)
    ..cubicTo(8, 68, 16, 82, 26, 78)
    ..cubicTo(30, 90, 44, 90, 46, 80)
    ..lineTo(46, 22)
    ..close();

  static const Offset _junction = Offset(38, 50);
  static const List<Offset> _nodes = [
    Offset(38, 29),
    Offset(27, 36),
    Offset(19, 50),
    Offset(27, 64),
    Offset(38, 71),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.translate(_shiftX, 0);

    final bounds = const Rect.fromLTWH(4, 2, 80, 96);
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_light, _dark],
    ).createShader(bounds);

    final line = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    final brain = _brain();
    final bar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(51, 4, 4, 92),
      const Radius.circular(2),
    );
    final collar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(55, 46, 6, 8),
      const Radius.circular(1),
    );
    final plates = [
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(61, 22, 9, 56),
        const Radius.circular(4),
      ),
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 32, 7, 36),
        const Radius.circular(3.5),
      ),
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(81, 42, 4, 16),
        const Radius.circular(2),
      ),
    ];

    if (glow) {
      final glowPaint = Paint()
        ..color = _light.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(
        brain,
        Paint.from(glowPaint)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      for (final r in [bar, collar, ...plates]) {
        canvas.drawRRect(r, glowPaint);
      }
    }

    canvas.drawPath(brain, line..strokeWidth = detailed ? 3.2 : 4.6);
    canvas.drawRRect(bar, fill);
    canvas.drawRRect(collar, fill);
    for (final plate in plates) {
      canvas.drawRRect(plate, fill);
    }

    if (detailed) {
      line.strokeWidth = 2.4;
      // Traces stop at the edge of each node ring, so the rings stay hollow.
      const ringRadius = 3.2;
      for (final node in _nodes) {
        final dir = (node - _junction) / (node - _junction).distance;
        canvas.drawLine(_junction, node - dir * ringRadius, line);
        canvas.drawCircle(node, ringRadius, line);
      }
      canvas.drawLine(_junction, const Offset(46, 50), line);
      canvas.drawCircle(_junction, 3.2, fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AtlasLogoPainter old) =>
      old.glow != glow || old.detailed != detailed;
}
