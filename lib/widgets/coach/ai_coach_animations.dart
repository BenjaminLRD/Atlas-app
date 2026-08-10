import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Glowing AI Orb Avatar animation widget for AI Coach header and floating controls.
class AiCoachOrbAnimation extends StatefulWidget {
  final double size;

  const AiCoachOrbAnimation({
    super.key,
    this.size = 64.0,
  });

  @override
  State<AiCoachOrbAnimation> createState() => _AiCoachOrbAnimationState();
}

class _AiCoachOrbAnimationState extends State<AiCoachOrbAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(angle),
              colors: const [
                Color(0xFF32D74B),
                Color(0xFF00E5FF),
                Color(0xFF7C4DFF),
                Color(0xFF32D74B),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                blurRadius: widget.size * 0.4,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF101213),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryContainer,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated typing indicator with wave dots when AI Coach is generating advice.
class AiCoachThinkingWave extends StatefulWidget {
  const AiCoachThinkingWave({super.key});

  @override
  State<AiCoachThinkingWave> createState() => _AiCoachThinkingWaveState();
}

class _AiCoachThinkingWaveState extends State<AiCoachThinkingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay) % 1.0;
            final translateY = math.sin(progress * math.pi) * -6.0;

            return Transform.translate(
              offset: Offset(0, translateY < 0 ? translateY : 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
