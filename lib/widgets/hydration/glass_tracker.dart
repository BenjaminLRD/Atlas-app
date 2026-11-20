import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/hydration.dart';

/// One glass per 250 ml of the daily target, each filled by the amount
/// actually drunk. 375 ml fills one glass and half of the next: the recorded
/// amount is never rounded to fit.
class GlassTracker extends StatelessWidget {
  const GlassTracker({
    super.key,
    required this.consumedMl,
    required this.goalMl,
  });

  final int consumedMl;
  final int goalMl;

  @override
  Widget build(BuildContext context) {
    final fills = GlassMath.fills(consumedMl, goalMl);
    if (fills.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 320.0;
        final maxCols = w < 300 ? 5 : (w < 380 ? 6 : 8);
        final rows = (fills.length / maxCols).ceil();
        final cols = (fills.length / rows).ceil();
        const gap = 8.0;
        final glassW = math.min(46.0, (w - gap * (cols - 1)) / cols);
        final glassH = glassW * 1.3;
        return Semantics(
          label:
              '${GlassMath.glassLabel(GlassMath.glassesConsumed(consumedMl))} '
              'of ${fills.length} glasses',
          child: Column(
            key: const Key('glass_tracker'),
            children: [
              for (var r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (
                      var i = r * cols;
                      i < math.min((r + 1) * cols, fills.length);
                      i++
                    ) ...[
                      if (i > r * cols) const SizedBox(width: gap),
                      _Glass(
                        key: Key('glass_$i'),
                        fill: fills[i],
                        width: glassW,
                        height: glassH,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    super.key,
    required this.fill,
    required this.width,
    required this.height,
  });

  final double fill;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fill),
      duration: const Duration(milliseconds: 250),
      builder: (context, v, _) => CustomPaint(
        size: Size(width, height),
        painter: _GlassPainter(
          fill: v,
          dark: context.isDarkMode,
          outline: context.appOutlineVariant,
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.fill,
    required this.dark,
    required this.outline,
  });

  final double fill;
  final bool dark;
  final Color outline;

  @override
  void paint(Canvas canvas, Size s) {
    // A tapered glass, wider at the rim.
    final inset = s.width * 0.12;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width - inset, s.height)
      ..lineTo(inset, s.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = dark ? const Color(0xFF2A2F34) : const Color(0xFFE3E8EB),
    );

    if (fill > 0) {
      canvas.save();
      canvas.clipPath(path);
      final top = s.height * (1 - fill);
      final water = Path()
        ..moveTo(0, s.height)
        ..lineTo(0, top);
      // A gentle surface: flat when the glass is full or nearly empty.
      final wave = (fill < 0.98 && fill > 0.02) ? s.height * 0.035 : 0.0;
      for (double x = 0; x <= s.width; x += 2) {
        water.lineTo(x, top + math.sin(x / s.width * 2 * math.pi) * wave);
      }
      water
        ..lineTo(s.width, s.height)
        ..close();
      canvas.drawPath(
        water,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF34D399), Color(0xFF059669)],
          ).createShader(Offset.zero & s),
      );
      // A soft highlight along the left edge.
      canvas.drawRect(
        Rect.fromLTWH(s.width * 0.14, top, s.width * 0.1, s.height - top),
        Paint()..color = Colors.white.withValues(alpha: 0.16),
      );
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = fill > 0
            ? const Color(0xFF34D399).withValues(alpha: 0.9)
            : outline,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) =>
      old.fill != fill || old.dark != dark || old.outline != outline;
}
