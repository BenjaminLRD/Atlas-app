import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Micro-Animations Design System Component.
class AppAnimation {
  /// Checkbox / Item Toggle micro scale-bounce wrapper
  static Widget scaleBounce({
    required bool active,
    required Widget child,
    Duration duration = AppDurations.fast,
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

  /// Smooth Slide-Fade Entrance Animation
  static Widget slideFadeIn({
    required Widget child,
    Duration duration = AppDurations.medium,
    Duration delay = Duration.zero,
    Offset offset = const Offset(0.0, 0.15),
    Curve curve = AppCurves.smoothOut,
  }) {
    return _SlideFadeInWidget(
      duration: duration,
      delay: delay,
      offset: offset,
      curve: curve,
      child: child,
    );
  }

  /// Elastic Scale-In Animation for Badges, Modals, and Cards
  static Widget scaleIn({
    required Widget child,
    Duration duration = AppDurations.medium,
    Curve curve = AppCurves.spring,
  }) {
    return _ScaleInWidget(
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  /// Premium Shimmer Loading/Highlight Effect Container
  static Widget shimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
    Duration duration = AppDurations.shimmer,
  }) {
    return _ShimmerWidget(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: duration,
      child: child,
    );
  }

  /// Smooth Animated Counter for Numbers (XP, Streak, Calories, Volume)
  static Widget countNumber({
    required int endValue,
    int startValue = 0,
    Duration duration = AppDurations.countUp,
    TextStyle? style,
    String prefix = '',
    String suffix = '',
  }) {
    return _AnimatedCountNumberWidget(
      startValue: startValue,
      endValue: endValue,
      duration: duration,
      style: style,
      prefix: prefix,
      suffix: suffix,
    );
  }

  /// Celebration Confetti Particle Burst Overlay Widget
  static Widget confettiParticles({
    required Widget child,
    bool isAnimating = true,
    int particleCount = 40,
  }) {
    return _ConfettiParticlesWidget(
      isAnimating: isAnimating,
      particleCount: particleCount,
      child: child,
    );
  }

  /// Staggered Animated List Container
  static Widget staggeredList({
    required List<Widget> children,
    Duration durationPerItem = const Duration(milliseconds: 250),
    Duration staggerDelay = const Duration(milliseconds: 60),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(children.length, (index) {
        return slideFadeIn(
          delay: Duration(milliseconds: index * staggerDelay.inMilliseconds),
          duration: durationPerItem,
          child: children[index],
        );
      }),
    );
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

class _ScaleBounceWidgetState extends State<_ScaleBounceWidget>
    with SingleTickerProviderStateMixin {
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

class _PulseGlowWidgetState extends State<_PulseGlowWidget>
    with SingleTickerProviderStateMixin {
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

class _SlideFadeInWidget extends StatefulWidget {
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;
  final Widget child;

  const _SlideFadeInWidget({
    required this.duration,
    required this.delay,
    required this.offset,
    required this.curve,
    required this.child,
  });

  @override
  State<_SlideFadeInWidget> createState() => _SlideFadeInWidgetState();
}

class _SlideFadeInWidgetState extends State<_SlideFadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _ScaleInWidget extends StatefulWidget {
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _ScaleInWidget({
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  State<_ScaleInWidget> createState() => _ScaleInWidgetState();
}

class _ScaleInWidgetState extends State<_ScaleInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

class _ShimmerWidget extends StatefulWidget {
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final Widget child;

  const _ShimmerWidget({
    this.baseColor,
    this.highlightColor,
    required this.duration,
    required this.child,
  });

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final base = widget.baseColor ??
        (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04));
    final highlight = widget.highlightColor ??
        (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

class _AnimatedCountNumberWidget extends StatefulWidget {
  final int startValue;
  final int endValue;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const _AnimatedCountNumberWidget({
    required this.startValue,
    required this.endValue,
    required this.duration,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<_AnimatedCountNumberWidget> createState() => _AnimatedCountNumberWidgetState();
}

class _AnimatedCountNumberWidgetState extends State<_AnimatedCountNumberWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _countAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _countAnimation = IntTween(
      begin: widget.startValue,
      end: widget.endValue,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.smoothOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCountNumberWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endValue != widget.endValue) {
      _controller.duration = widget.duration;
      _countAnimation = IntTween(
        begin: oldWidget.endValue,
        end: widget.endValue,
      ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.smoothOut));
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
      animation: _countAnimation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_countAnimation.value}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

class _ConfettiParticlesWidget extends StatefulWidget {
  final bool isAnimating;
  final int particleCount;
  final Widget child;

  const _ConfettiParticlesWidget({
    required this.isAnimating,
    required this.particleCount,
    required this.child,
  });

  @override
  State<_ConfettiParticlesWidget> createState() => _ConfettiParticlesWidgetState();
}

class _ConfettiParticlesWidgetState extends State<_ConfettiParticlesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _particles = List.generate(widget.particleCount, (_) => _Particle.random());

    if (widget.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_ConfettiParticlesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
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
    return Stack(
      children: [
        widget.child,
        if (widget.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _controller.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  factory _Particle.random() {
    final rng = math.Random();
    final colors = [
      const Color(0xFF32D74B),
      const Color(0xFFFFD700),
      const Color(0xFF00E5FF),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF3B30),
    ];
    return _Particle(
      x: 0.5 + (rng.nextDouble() - 0.5) * 0.3,
      y: 0.4 + (rng.nextDouble() - 0.5) * 0.2,
      vx: (rng.nextDouble() - 0.5) * 1.5,
      vy: -0.8 - rng.nextDouble() * 1.2,
      color: colors[rng.nextInt(colors.length)],
      size: 4 + rng.nextDouble() * 6,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final currentX = (p.x + p.vx * progress) * size.width;
      final currentY = (p.y + p.vy * progress + 1.2 * progress * progress) * size.height;

      canvas.drawCircle(Offset(currentX, currentY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
