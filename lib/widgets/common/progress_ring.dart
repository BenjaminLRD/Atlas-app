import 'dart:math';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

class ProgressRingItem {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double strokeWidth;

  const ProgressRingItem({
    required this.progress,
    required this.color,
    this.strokeWidth = 10.0,
  });
}

class ProgressRing extends StatelessWidget {
  final double size;
  final List<ProgressRingItem> rings;
  final Widget? centerChild;

  const ProgressRing({
    super.key,
    this.size = 180,
    required this.rings,
    this.centerChild,
  });

  factory ProgressRing.single({
    double size = 180,
    required double progress,
    required Color color,
    double strokeWidth = 12.0,
    Widget? centerChild,
  }) {
    return ProgressRing(
      size: size,
      rings: [
        ProgressRingItem(
          progress: progress,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ],
      centerChild: centerChild,
    );
  }

  factory ProgressRing.activityRings({
    double size = 180,
    required double streakProgress,
    required double caloriesProgress,
    required double proteinProgress,
    Widget? centerChild,
  }) {
    return ProgressRing(
      size: size,
      rings: [
        ProgressRingItem(progress: streakProgress, color: AppColors.ringStreak, strokeWidth: 10),
        ProgressRingItem(progress: caloriesProgress, color: AppColors.ringCalories, strokeWidth: 10),
        ProgressRingItem(progress: proteinProgress, color: AppColors.ringProtein, strokeWidth: 10),
      ],
      centerChild: centerChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingsPainter(rings: rings),
          ),
          ?centerChild,
        ],
      ),
    );
  }
}

class _ProgressRingsPainter extends CustomPainter {
  final List<ProgressRingItem> rings;

  _ProgressRingsPainter({required this.rings});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double currentRadius = (min(size.width, size.height) / 2) - 8;

    for (final ring in rings) {
      if (currentRadius <= 0) break;

      // Track paint (faint background)
      final trackPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.strokeWidth;

      canvas.drawCircle(center, currentRadius, trackPaint);

      // Arc progress paint
      final progressPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ring.strokeWidth;

      final sweepAngle = 2 * pi * ring.progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: currentRadius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      currentRadius -= (ring.strokeWidth + 6);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingsPainter oldDelegate) => true;
}
