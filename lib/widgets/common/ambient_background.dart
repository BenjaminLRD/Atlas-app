import 'dart:ui';
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
    )..repeat(reverse: true);
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
        // 1. Light Mode Premium Soft Gradient (#EAF8EE -> #F8FCF8 -> #F2FBF4)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: context.appBackgroundGradient,
            ),
          ),
        ),

        // 2. Soft Ambient Organic Blobs (Opacity 3% - 6%)
        if (!disableAnimations)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final animVal = _controller.value;
              return Stack(
                children: [
                  Positioned(
                    top: -60 + (animVal * 25),
                    right: -50 - (animVal * 15),
                    child: _buildBlob(240, AppColors.primaryContainer.withValues(alpha: 0.05)),
                  ),
                  Positioned(
                    bottom: 140 - (animVal * 30),
                    left: -60 + (animVal * 20),
                    child: _buildBlob(280, AppColors.primaryFixed.withValues(alpha: 0.04)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.45 + (animVal * 15),
                    right: -40 + (animVal * 10),
                    child: _buildBlob(200, AppColors.secondaryContainer.withValues(alpha: 0.04)),
                  ),
                ],
              );
            },
          )
        else
          Stack(
            children: [
              Positioned(
                top: -60,
                right: -50,
                child: _buildBlob(240, AppColors.primaryContainer.withValues(alpha: 0.05)),
              ),
              Positioned(
                bottom: 140,
                left: -60,
                child: _buildBlob(280, AppColors.primaryFixed.withValues(alpha: 0.04)),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.45,
                right: -40,
                child: _buildBlob(200, AppColors.secondaryContainer.withValues(alpha: 0.04)),
              ),
            ],
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
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
