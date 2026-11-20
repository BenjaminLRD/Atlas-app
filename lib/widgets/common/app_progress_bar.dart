import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Progress Bar matching the Atlas Vitality Design System.
/// Features:
/// - Rounded pill ends (`BorderRadius.circular(999)`).
/// - Smooth animated fill transitions with configurable duration.
/// - Subtle green glow on active progress bar.
/// - Optional gradient or solid color fill.
class AppProgressBar extends StatelessWidget {
  final double value; // Progress between 0.0 and 1.0
  final double height;
  final Color? progressColor;
  final Color? trackColor;
  final Gradient? gradient;
  final bool showGlow;
  final Duration duration;
  final Curve curve;
  final BorderRadiusGeometry? borderRadius;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.progressColor,
    this.trackColor,
    this.gradient,
    this.showGlow = true,
    this.duration = AppDurations.medium,
    this.curve = Curves.easeOutCubic,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final effectiveTrackColor =
        trackColor ??
        (context.isDarkMode
            ? const Color(0xFF25292C)
            : AppColors.surfaceContainerLow);
    final effectiveProgressColor =
        progressColor ??
        (context.isDarkMode ? AppColors.darkPrimary : AppColors.primary);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(999);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return ClipRRect(
          borderRadius: effectiveRadius,
          child: Container(
            height: height,
            width: totalWidth,
            decoration: BoxDecoration(
              color: effectiveTrackColor,
              borderRadius: effectiveRadius,
            ),
            child: Stack(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: clampedValue),
                  duration: duration,
                  curve: curve,
                  builder: (context, animValue, child) {
                    final progressWidth = totalWidth * animValue;

                    if (progressWidth <= 0.0) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: progressWidth,
                      height: height,
                      decoration: BoxDecoration(
                        color: gradient == null ? effectiveProgressColor : null,
                        gradient: gradient,
                        borderRadius: effectiveRadius,
                        boxShadow: showGlow
                            ? [
                                BoxShadow(
                                  color: effectiveProgressColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
