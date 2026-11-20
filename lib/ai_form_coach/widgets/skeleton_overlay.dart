import 'package:flutter/material.dart';
import '../models/pose_landmark.dart';

/// Interactive skeleton overlay rendering real-time or playback body joints and connections.
class SkeletonOverlay extends StatelessWidget {
  final List<PoseLandmark> landmarks;
  final bool hasWarnings;
  final bool isGoodForm;
  final double strokeWidth;

  const SkeletonOverlay({
    super.key,
    required this.landmarks,
    this.hasWarnings = false,
    this.isGoodForm = true,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkeletonPainter(
        landmarks: landmarks,
        hasWarnings: hasWarnings,
        isGoodForm: isGoodForm,
        strokeWidth: strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final bool hasWarnings;
  final bool isGoodForm;
  final double strokeWidth;

  _SkeletonPainter({
    required this.landmarks,
    required this.hasWarnings,
    required this.isGoodForm,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final Color boneColor = hasWarnings
        ? const Color(0xFFEF4444) // Red for active warnings
        : isGoodForm
        ? const Color(0xFF10B981) // Vibrant emerald for good form
        : const Color(0xFFF59E0B); // Amber for minor correction

    final bonePaint = Paint()
      ..color = boneColor.withValues(alpha: 0.85)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final jointGlowPaint = Paint()
      ..color = boneColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Fast coordinate lookup
    Offset? point(String name) {
      final search = name.toLowerCase().replaceAll('_', '');
      for (final lm in landmarks) {
        if (lm.name.toLowerCase().replaceAll('_', '') == search) {
          if (lm.confidence < 0.3) return null;
          return Offset(lm.x * size.width, lm.y * size.height);
        }
      }
      return null;
    }

    void drawBone(String fromName, String toName) {
      final a = point(fromName);
      final b = point(toName);
      if (a != null && b != null) {
        canvas.drawLine(a, b, bonePaint);
      }
    }

    // 1. Draw Torso & Spine
    drawBone(PoseLandmarkNames.leftShoulder, PoseLandmarkNames.rightShoulder);
    drawBone(PoseLandmarkNames.leftHip, PoseLandmarkNames.rightHip);
    drawBone(PoseLandmarkNames.leftShoulder, PoseLandmarkNames.leftHip);
    drawBone(PoseLandmarkNames.rightShoulder, PoseLandmarkNames.rightHip);

    // 2. Draw Upper Limbs
    drawBone(PoseLandmarkNames.leftShoulder, PoseLandmarkNames.leftElbow);
    drawBone(PoseLandmarkNames.leftElbow, PoseLandmarkNames.leftWrist);
    drawBone(PoseLandmarkNames.rightShoulder, PoseLandmarkNames.rightElbow);
    drawBone(PoseLandmarkNames.rightElbow, PoseLandmarkNames.rightWrist);

    // 3. Draw Lower Limbs
    drawBone(PoseLandmarkNames.leftHip, PoseLandmarkNames.leftKnee);
    drawBone(PoseLandmarkNames.leftKnee, PoseLandmarkNames.leftAnkle);
    drawBone(PoseLandmarkNames.rightHip, PoseLandmarkNames.rightKnee);
    drawBone(PoseLandmarkNames.rightKnee, PoseLandmarkNames.rightAnkle);

    // 4. Draw Joint Nodes
    for (final lm in landmarks) {
      if (lm.confidence < 0.3) continue;
      final center = Offset(lm.x * size.width, lm.y * size.height);
      // Glow
      canvas.drawCircle(center, strokeWidth * 2.2, jointGlowPaint);
      // Center node
      canvas.drawCircle(center, strokeWidth * 1.2, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.hasWarnings != hasWarnings ||
        oldDelegate.isGoodForm != isGoodForm;
  }
}
