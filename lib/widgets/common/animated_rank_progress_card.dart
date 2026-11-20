import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_card.dart';

/// Reusable animated rank progression card widget for Dashboard and Profile screens.
class AnimatedRankProgressCard extends StatelessWidget {
  final String currentRank;
  final String nextRank;

  /// Ranked points (verified milestone levels) and the points needed for
  /// [nextRank].
  final int currentPoints;
  final int targetPoints;

  /// Milestones still needed for [nextRank]. Defaults to the gap between
  /// [targetPoints] and [currentPoints].
  final int? milestonesToNext;

  /// At the highest rank there is no next target.
  final bool isMaxRank;
  final VoidCallback? onTap;

  const AnimatedRankProgressCard({
    super.key,
    required this.currentRank,
    required this.nextRank,
    required this.currentPoints,
    required this.targetPoints,
    this.milestonesToNext,
    this.isMaxRank = false,
    this.onTap,
  });

  Color _getRankColor(String rank) {
    switch (rank.toLowerCase()) {
      case 'legend':
      case 'legendary':
        return const Color(0xFFFFD700); // Gold
      case 'diamond':
        return const Color(0xFF00E5FF); // Cyan
      case 'platinum':
        return const Color(0xFFE0E0E0); // Platinum
      case 'gold':
        return const Color(0xFFFFB300); // Gold Yellow
      case 'silver':
        return const Color(0xFFB0BEC5); // Silver
      case 'bronze':
      default:
        return const Color(0xFFCD7F32); // Bronze
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _getRankColor(currentRank);
    final progressFactor = isMaxRank
        ? 1.0
        : targetPoints > 0
        ? (currentPoints / targetPoints).clamp(0.0, 1.0)
        : 1.0;
    final remaining =
        milestonesToNext ??
        (targetPoints > currentPoints ? targetPoints - currentPoints : 0);

    return AppCard(
      onTap: onTap,
      backgroundColor: const Color(0xFF1E1535),
      borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Rank Header & Emblem + View Ranked Button
          Row(
            children: [
              AppAnimation.pulseGlow(
                color: rankColor,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rankColor.withValues(alpha: 0.18),
                    border: Border.all(color: rankColor, width: 2),
                  ),
                  child: Icon(Icons.shield_rounded, color: rankColor, size: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT RANK',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFA78BFA),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentRank.toUpperCase(),
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: Color(0xFFC4B5FD),
                      ),
                      SizedBox(width: 2),
                      Text(
                        'View Ranked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC4B5FD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Progress Bar Fill
          ClipRRect(
            borderRadius: AppRadii.borderFull,
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  TweenAnimationBuilder<double>(
                    duration: AppDurations.countUp,
                    curve: AppCurves.smoothOut,
                    tween: Tween<double>(begin: 0.0, end: progressFactor),
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. Progress Detail Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isMaxRank
                      ? 'Max rank reached'
                      : '$remaining ${remaining == 1 ? 'milestone' : 'milestones'} to $nextRank',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progressFactor * 100).toInt()}%',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
