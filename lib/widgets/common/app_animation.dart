import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Micro-Animations Design System Component.
class AppAnimation {
  /// Checkbox / Item Toggle micro scale-bounce wrapper
  static Widget scaleBounce({
    required bool active,
    required Widget child,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    return _ScaleBounceWidget(active: active, duration: duration, child: child);
  }

  /// Ambient Radial Glow Pulse Animation Container
  static Widget pulseGlow({
    required Widget child,
    Color? color,
    Duration duration = const Duration(seconds: 3),
  }) {
    return _PulseGlowWidget(duration: duration, color: color, child: child);
  }
}

class _ScaleBounceWidget extends StatefulWidget {
  final bool active;
  final Duration duration;
  final Widget child;

  const _ScaleBounceWidget({
    required this.active,
    required this.duration,
    required this.child,
  });

  @override
  State<_ScaleBounceWidget> createState() => _ScaleBounceWidgetState();
}

class _ScaleBounceWidgetState extends State<_ScaleBounceWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.18), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.18, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_ScaleBounceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PulseGlowWidget extends StatefulWidget {
  final Duration duration;
  final Color? color;
  final Widget child;

  const _PulseGlowWidget({
    required this.duration,
    this.color,
    required this.child,
  });

  @override
  State<_PulseGlowWidget> createState() => _PulseGlowWidgetState();
}

class _PulseGlowWidgetState extends State<_PulseGlowWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (!tickerEnabled || disableAnimations) {
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
    final glowColor = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_controller.value * 0.5),
          child: Transform.scale(
            scale: 0.95 + (_controller.value * 0.1),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: context.isDarkMode ? 0.25 : 0.12),
              blurRadius: 50,
              spreadRadius: 15,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
