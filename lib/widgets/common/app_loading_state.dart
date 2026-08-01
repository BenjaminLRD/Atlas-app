import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Reusable Shimmer/Pulse Skeleton Box Widget for Loading Placeholders.
class AppSkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadii.md,
    this.margin,
  });

  const AppSkeletonBox.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = AppRadii.full;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow * 2,
    );
    _opacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (!tickerEnabled || disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
    } else {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    Widget box = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: context.appOutlineVariant.withValues(
          alpha: context.isDarkMode ? 0.25 : 0.4,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    );

    if (disableAnimations) return box;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) => Opacity(
        opacity: _opacityAnimation.value,
        child: child,
      ),
      child: box,
    );
  }
}

/// Skeleton Card Loader for Dashboard, Profile, and Analytics Views.
class AppSkeletonCard extends StatelessWidget {
  final double height;

  const AppSkeletonCard({super.key, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const AppSkeletonBox.circle(size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeletonBox(width: 140, height: 14),
                    SizedBox(height: AppSpacing.xs),
                    AppSkeletonBox(width: 90, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSkeletonBox(width: double.infinity, height: height - 80),
        ],
      ),
    );
  }
}

/// Skeleton Chart Card Loader.
class AppSkeletonChart extends StatelessWidget {
  const AppSkeletonChart({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonBox(width: 120, height: 16),
              AppSkeletonBox(width: 60, height: 24, borderRadius: AppRadii.full),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          AppSkeletonBox(width: double.infinity, height: 160),
        ],
      ),
    );
  }
}

/// Universal Page / Section Loading Spinner & Placeholder.
class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
