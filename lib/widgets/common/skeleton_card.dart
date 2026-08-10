import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Flutter native shimmer animation component for skeleton loading placeholders.
class SkeletonCard extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final baseColor = isDark ? const Color(0xFF1B1D24) : Colors.grey.shade200;
    final highlightColor = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer skeleton matching Bento Grid Training Overview
class SkeletonAnalyticsCard extends StatelessWidget {
  const SkeletonAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonCard(width: 140, height: 14, borderRadius: 4),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: List.generate(4, (_) => const SkeletonCard(height: 90)),
        ),
      ],
    );
  }
}

/// Shimmer skeleton matching Donut Chart Muscle Balance
class SkeletonChartCard extends StatelessWidget {
  const SkeletonChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonCard(width: 120, height: 14, borderRadius: 4),
              SkeletonCard(width: 80, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SkeletonCard(width: 130, height: 130, borderRadius: 65),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: List.generate(
                    4,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SkeletonCard(height: 24, borderRadius: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton matching Workout Timeline
class SkeletonTimelineCard extends StatelessWidget {
  const SkeletonTimelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonCard(width: 14, height: 14, borderRadius: 7),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonCard(width: 100, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonCard(height: 80, borderRadius: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
