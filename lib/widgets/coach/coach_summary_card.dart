import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recommendation.dart';
import '../../providers/fitness_provider.dart';
import '../../screens/ai_coach_screen.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';

/// A dashboard summary card displaying active AI Coach recommendations count,
/// highest priority advice preview, and a direct navigation action to AICoachScreen.
class CoachSummaryCard extends StatelessWidget {
  final List<Recommendation>? recommendations;
  final VoidCallback? onViewAdviceTap;

  const CoachSummaryCard({
    super.key,
    this.recommendations,
    this.onViewAdviceTap,
  });

  @override
  Widget build(BuildContext context) {
    // Obtain active recommendations reactively from provider if not explicitly passed
    final activeRecs = recommendations ?? FitnessProvider.instance.recommendations;
    final activeCount = activeRecs.length;

    // Determine top recommendation (High priority first, then earliest created)
    Recommendation? topRec;
    if (activeRecs.isNotEmpty) {
      topRec = activeRecs.firstWhere(
        (r) => r.priority == RecommendationPriority.high,
        orElse: () => activeRecs.first,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      backgroundColor: context.appCardBg,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: AI Avatar Icon + Title + Recommendation Count Badge
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Coach',
                      style: AppTheme.bodyLg.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      activeCount > 0
                          ? '$activeCount active ${activeCount == 1 ? "recommendation" : "recommendations"}'
                          : 'All targets on track',
                      style: AppTheme.labelCaps.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (activeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: AppRadii.borderFull,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$activeCount',
                        style: AppTheme.labelCaps.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Highest Priority Advice Preview
          if (topRec != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: topRec.priority == RecommendationPriority.high
                    ? Colors.amber.withValues(alpha: 0.1)
                    : context.isDarkMode
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                borderRadius: AppRadii.borderMd,
                border: Border.all(
                  color: topRec.priority == RecommendationPriority.high
                      ? Colors.amber.withValues(alpha: 0.3)
                      : context.appCardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        topRec.priority == RecommendationPriority.high
                            ? Icons.warning_amber_rounded
                            : Icons.tips_and_updates_outlined,
                        size: 16,
                        color: topRec.priority == RecommendationPriority.high
                            ? Colors.amber[700]
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          topRec.title,
                          style: AppTheme.bodyMd.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topRec.description,
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.08),
                borderRadius: AppRadii.borderMd,
              ),
              child: Text(
                'You\'re all caught up! Your training and nutrition targets are aligned.',
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Navigation Button Action
          AppButton.primary(
            label: 'VIEW ADVICE',
            icon: Icons.arrow_forward_rounded,
            isFullWidth: true,
            onPressed: onViewAdviceTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AICoachScreen(),
                    ),
                  );
                },
          ),
        ],
      ),
    );
  }
}
