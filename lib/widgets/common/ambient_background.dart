import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Renders a soft ambient background with smooth gradients and subtle organic
/// depth circles for Light Mode (inspired by Apple Fitness / WHOOP / Oura),
/// while preserving Dark Mode completely untouched.
class AmbientBackground extends StatefulWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final isDark = context.isDarkMode;

    if (!tickerEnabled || disableAnimations || isDark) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isDarkMode) {
      return Container(
        color: context.appBackground,
        child: widget.child,
      );
    }

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Stack(
      children: [
        ExcludeSemantics(
          child: Stack(
            children: [
              // 1. Light Mode Premium Soft Gradient (#EAF8EE -> #F8FCF8 -> #F2FBF4)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: context.appBackgroundGradient,
                  ),
                ),
              ),

              // 2. Soft Ambient Organic Blobs wrapped in RepaintBoundary for zero foreground repaint impact
              if (!disableAnimations)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final animVal = _controller.value;
                      return Stack(
                        children: [
                          Positioned(
                            top: -60 + (animVal * 25),
                            right: -50 - (animVal * 15),
                            child: _buildBlob(240, AppColors.primaryContainer.withValues(alpha: 0.12)),
                          ),
                          Positioned(
                            bottom: 140 - (animVal * 30),
                            left: -60 + (animVal * 20),
                            child: _buildBlob(280, AppColors.primaryFixed.withValues(alpha: 0.10)),
                          ),
                          Positioned(
                            top: MediaQuery.of(context).size.height * 0.45 + (animVal * 15),
                            right: -40 + (animVal * 10),
                            child: _buildBlob(200, AppColors.secondaryContainer.withValues(alpha: 0.10)),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Stack(
                  children: [
                    Positioned(
                      top: -60,
                      right: -50,
                      child: _buildBlob(240, AppColors.primaryContainer.withValues(alpha: 0.12)),
                    ),
                    Positioned(
                      bottom: 140,
                      left: -60,
                      child: _buildBlob(280, AppColors.primaryFixed.withValues(alpha: 0.10)),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45,
                      right: -40,
                      child: _buildBlob(200, AppColors.secondaryContainer.withValues(alpha: 0.10)),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // 3. Foreground Child Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.25, 1.0],
        ),
      ),
    );
  }
}
