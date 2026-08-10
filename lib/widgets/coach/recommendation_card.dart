import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recommendation.dart';
import '../../providers/fitness_provider.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';
import 'coach_action_handler.dart';

/// Renders an individual AI recommendation with category badge, priority styling,
/// explainable reasoning, metric trigger chip, primary action route button, and dismissal action.
class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback? onActionTap;
  final VoidCallback? onDismissTap;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onActionTap,
    this.onDismissTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHighPriority = recommendation.priority == RecommendationPriority.high;
    final isMediumPriority = recommendation.priority == RecommendationPriority.medium;

    final priorityColor = isHighPriority
        ? const Color(0xFFD97706) // Urgent Amber/Orange
        : isMediumPriority
            ? const Color(0xFF2563EB) // Blue
            : AppColors.primary; // Green

    final categoryDetails = _getCategoryDetails(recommendation.category);
    final hasAction = recommendation.actionTitle.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: context.appCardBg,
      borderColor: isHighPriority
          ? priorityColor.withValues(alpha: 0.5)
          : context.appCardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Badge + Priority Pill + Dismiss Button
          Row(
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: categoryDetails.color.withValues(alpha: 0.15),
                  borderRadius: AppRadii.borderFull,
                  border: Border.all(
                    color: categoryDetails.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryDetails.icon,
                      size: 13,
                      color: categoryDetails.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      categoryDetails.label,
                      style: AppTheme.labelCaps.copyWith(
                        color: categoryDetails.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Priority Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: AppRadii.borderSm,
                ),
                child: Text(
                  recommendation.priority.name.toUpperCase(),
                  style: AppTheme.labelCaps.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),

              const Spacer(),

              // Dismissal Button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: context.appTextSecondary,
                tooltip: 'Dismiss recommendation',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismissTap ??
                    () {
                      FitnessProvider.instance.dismissRecommendation(recommendation.id);
                    },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Title
          Text(
            recommendation.title,
            style: AppTheme.bodyLg.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            recommendation.description,
            style: AppTheme.bodyMd.copyWith(
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),

          // Reasoning Section ("Why this advice")
          if (recommendation.reasoning.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: AppRadii.borderMd,
                border: Border.all(
                  color: context.appCardBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WHY THIS ADVICE',
                          style: AppTheme.labelCaps.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recommendation.reasoning,
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Metric Trigger Chip
          if (recommendation.metricTrigger != null && recommendation.metricTrigger!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Trigger: ${recommendation.metricTrigger}',
                        style: AppTheme.labelCaps.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Primary Action Button
          if (hasAction) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: recommendation.actionTitle,
              icon: Icons.chevron_right_rounded,
              isFullWidth: true,
              onPressed: onActionTap ??
                  () {
                    CoachActionHandler.handleAction(
                      context,
                      recommendation.actionRoute,
                    );
                  },
            ),
          ],
        ],
      ),
    );
  }

  _CategoryDetails _getCategoryDetails(RecommendationCategory category) {
    switch (category) {
      case RecommendationCategory.training:
        return const _CategoryDetails(
          label: 'TRAINING',
          color: Color(0xFF10B981), // Emerald
          icon: Icons.fitness_center_rounded,
        );
      case RecommendationCategory.nutrition:
        return const _CategoryDetails(
          label: 'NUTRITION',
          color: Color(0xFFF59E0B), // Amber
          icon: Icons.restaurant_rounded,
        );
      case RecommendationCategory.recovery:
        return const _CategoryDetails(
          label: 'RECOVERY',
          color: Color(0xFF3B82F6), // Blue
          icon: Icons.bedtime_rounded,
        );
      case RecommendationCategory.gamification:
        return const _CategoryDetails(
          label: 'GAMIFICATION',
          color: Color(0xFF8B5CF6), // Purple
          icon: Icons.emoji_events_rounded,
        );
      case RecommendationCategory.mindset:
        return const _CategoryDetails(
          label: 'MINDSET',
          color: Color(0xFFEC4899), // Pink
          icon: Icons.psychology_rounded,
        );
    }
  }
}

class _CategoryDetails {
  final String label;
  final Color color;
  final IconData icon;

  const _CategoryDetails({
    required this.label,
    required this.color,
    required this.icon,
  });
}
