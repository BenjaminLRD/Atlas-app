import 'package:flutter/material.dart';

/// Circular form score gauge widget displaying 0-100 score and performance grade.
class FormScoreWidget extends StatelessWidget {
  final int score; // 0 to 100
  final double size;
  final bool showLabel;

  const FormScoreWidget({
    super.key,
    required this.score,
    this.size = 110.0,
    this.showLabel = true,
  });

  Color get scoreColor {
    if (score >= 85) return const Color(0xFF10B981); // Emerald
    if (score >= 70) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  String get gradeText {
    if (score >= 90) return 'ELITE FORM';
    if (score >= 80) return 'GOOD FORM';
    if (score >= 65) return 'FAIR';
    return 'ACTION NEEDED';
  }

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100);
    final color = scoreColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: size * 0.08,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              // Value progress
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: clampedScore / 100.0,
                  strokeWidth: size * 0.09,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              // Numeric Score
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$clampedScore',
                    style: TextStyle(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'SCORE',
                    style: TextStyle(
                      fontSize: size * 0.10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              gradeText,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
