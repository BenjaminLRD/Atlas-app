import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recommendation.dart';
import '../../providers/fitness_provider.dart';
import '../../screens/ai_coach_screen.dart';
import '../../screens/diet_plan_screen.dart';
import '../../screens/health_dashboard_screen.dart';
import '../../screens/weekly_workout_plan_screen.dart';
import '../../services/ai/insights/insight_model.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';

/// A dashboard summary card displaying proactive AI Coach insights,
/// active recommendations count, priority badges, contextual action buttons,
/// and an expandable "Why am I seeing this?" reasoning view.
class CoachSummaryCard extends StatefulWidget {
  final List<Recommendation>? recommendations;
  final CoachInsight? insight;
  final VoidCallback? onViewAdviceTap;

  const CoachSummaryCard({
    super.key,
    this.recommendations,
    this.insight,
    this.onViewAdviceTap,
  });

  @override
  State<CoachSummaryCard> createState() => _CoachSummaryCardState();
}

class _CoachSummaryCardState extends State<CoachSummaryCard> {
  bool _isReasoningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final activeRecs =
        widget.recommendations ?? FitnessProvider.instance.recommendations;
    final activeCount = activeRecs.length;

    // Use explicit proactive insight if provided, else fallback to top Recommendation
    final proactiveInsight = widget.insight;
    Recommendation? topRec;
    if (proactiveInsight == null && activeRecs.isNotEmpty) {
      topRec = activeRecs.firstWhere(
        (r) => r.priority == RecommendationPriority.high,
        orElse: () => activeRecs.first,
      );
    }

    // Determine badge and accent colors
    Color accentColor = AppColors.primary;
    IconData headerIcon = Icons.auto_awesome;
    String? badgeText;
    Color badgeBg = AppColors.primaryContainer.withValues(alpha: 0.2);
    Color badgeTextColor = AppColors.primary;

    if (proactiveInsight != null) {
      switch (proactiveInsight.priority) {
        case InsightPriority.critical:
          accentColor = AppColors.error;
          headerIcon = Icons.warning_rounded;
          badgeText = 'Critical';
          badgeBg = AppColors.error.withValues(alpha: 0.15);
          badgeTextColor = AppColors.error;
          break;
        case InsightPriority.high:
          accentColor = Colors.orangeAccent[700] ?? Colors.orange;
          headerIcon = Icons.priority_high_rounded;
          badgeText = 'High Priority';
          badgeBg = Colors.orange.withValues(alpha: 0.15);
          badgeTextColor = Colors.orangeAccent[700] ?? Colors.orange;
          break;
        case InsightPriority.medium:
          accentColor = AppColors.primary;
          headerIcon = Icons.tips_and_updates_rounded;
          badgeText = 'Tip';
          badgeBg = AppColors.primary.withValues(alpha: 0.15);
          badgeTextColor = AppColors.primary;
          break;
        case InsightPriority.low:
          accentColor = AppColors.secondary;
          headerIcon = Icons.bolt_rounded;
          badgeText = 'Momentum';
          badgeBg = AppColors.secondary.withValues(alpha: 0.15);
          badgeTextColor = AppColors.secondary;
          break;
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      backgroundColor: context.appCardBg,
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: AI Avatar Icon + Title + Priority/Count Badge
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(headerIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atlas AI',
                      style: AppTheme.bodyLg.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      proactiveInsight != null
                          ? proactiveInsight.type.code.replaceAll('_', ' ')
                          : (activeCount > 0
                                ? '$activeCount active ${activeCount == 1 ? "recommendation" : "recommendations"}'
                                : 'All targets on track'),
                      style: AppTheme.labelCaps.copyWith(
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (proactiveInsight != null && badgeText != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: AppRadii.borderFull,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: AppTheme.labelCaps.copyWith(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else if (activeCount > 0) ...[
                const SizedBox(width: AppSpacing.xs),
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Proactive Insight / Highest Priority Advice Preview
          if (proactiveInsight != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proactiveInsight.title,
                    style: AppTheme.bodyMd.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    proactiveInsight.message,
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Expandable "Why am I seeing this?" Section
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isReasoningExpanded = !_isReasoningExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isReasoningExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.help_outline_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isReasoningExpanded
                                ? 'Hide reason'
                                : 'Why am I seeing this?',
                            style: AppTheme.labelCaps.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isReasoningExpanded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: AppRadii.borderSm,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Reasoning',
                            style: AppTheme.labelCaps.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            proactiveInsight.rationale ??
                                'Generated because your physiological recovery and training load indicate that this adjustment will optimize progress.',
                            style: AppTheme.bodySm.copyWith(
                              color: context.appTextSecondary,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (topRec != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: topRec.priority == RecommendationPriority.high
                    ? Colors.amber.withValues(alpha: 0.1)
                    : (context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03)),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Contextual Action Button
          AppButton.secondary(
            label: proactiveInsight?.effectiveActionLabel ?? 'View Advice',
            icon: Icons.arrow_forward_rounded,
            isFullWidth: true,
            onPressed: () {
              if (widget.onViewAdviceTap != null) {
                widget.onViewAdviceTap!();
                return;
              }

              if (proactiveInsight != null) {
                switch (proactiveInsight.actionType) {
                  case InsightActionType.startWorkout:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WeeklyWorkoutPlanScreen(),
                      ),
                    );
                    break;
                  case InsightActionType.logProtein:
                  case InsightActionType.adjustCalories:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DietPlanScreen()),
                    );
                    break;
                  case InsightActionType.reviewRecovery:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HealthDashboardScreen(),
                      ),
                    );
                    break;
                  case InsightActionType.openAICoach:
                  case InsightActionType.viewProgress:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AICoachScreen()),
                    );
                    break;
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AICoachScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
