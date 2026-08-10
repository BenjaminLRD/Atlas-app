import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_card.dart';

/// Reusable animated rank progression card widget for Dashboard and Profile screens.
class AnimatedRankProgressCard extends StatelessWidget {
  final String currentRank;
  final String nextRank;
  final int currentXp;
  final int targetXp;
  final VoidCallback? onTap;

  const AnimatedRankProgressCard({
    super.key,
    required this.currentRank,
    required this.nextRank,
    required this.currentXp,
    required this.targetXp,
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
    final progressFactor = targetXp > 0 ? (currentXp / targetXp).clamp(0.0, 1.0) : 1.0;
    final remainingXp = targetXp > currentXp ? targetXp - currentXp : 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Rank Header & Badge Emblem
          Row(
            children: [
              AppAnimation.pulseGlow(
                color: rankColor,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rankColor.withValues(alpha: 0.15),
                    border: Border.all(color: rankColor, width: 2),
                  ),
                  child: Icon(
                    Icons.military_tech_rounded,
                    color: rankColor,
                    size: 28,
                  ),
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
                        color: context.appTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentRank.toUpperCase(),
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.15),
                  borderRadius: AppRadii.borderFull,
                  border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryContainer),
                    const SizedBox(width: 2),
                    AppAnimation.countNumber(
                      endValue: currentXp,
                      suffix: ' XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. XP Progress Bar Fill
          ClipRRect(
            borderRadius: AppRadii.borderFull,
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    color: context.isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  TweenAnimationBuilder<double>(
                    duration: AppDurations.countUp,
                    curve: AppCurves.smoothOut,
                    tween: Tween<double>(begin: 0.0, end: progressFactor),
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                rankColor,
                                AppColors.primaryContainer,
                              ],
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
              Text(
                '$remainingXp XP to $nextRank',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                '${(progressFactor * 100).toInt()}%',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
