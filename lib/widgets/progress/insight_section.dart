import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/fitness_insight.dart';
import '../../widgets/common/app_button.dart';

/// AI-ready Insight Section component displaying horizontal scrolling insight cards and detail bottom sheet.
class InsightSection extends StatelessWidget {
  final List<FitnessInsight> insights;

  const InsightSection({
    super.key,
    required this.insights,
  });

  IconData _getInsightIcon(String iconName) {
    switch (iconName) {
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'pie_chart':
        return Icons.pie_chart_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'performance':
        return AppColors.primaryContainer;
      case 'consistency':
        return Colors.orangeAccent;
      case 'strength':
        return Colors.lightBlueAccent;
      case 'balance':
        return Colors.tealAccent;
      case 'motivation':
        return Colors.purpleAccent;
      default:
        return AppColors.primaryContainer;
    }
  }

  void _showInsightDetailModal(BuildContext context, FitnessInsight insight) {
    final isDark = context.isDarkMode;
    final categoryColor = _getCategoryColor(insight.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getInsightIcon(insight.icon),
                            color: categoryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: AppTheme.headlineMd.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                insight.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: context.appOutlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 14),

                // Full Explanation
                Text(
                  'FULL EXPLANATION',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Supporting Metrics
                if (insight.metricSummary.isNotEmpty) ...[
                  _buildModalRow(
                    context,
                    'Supporting Metrics',
                    insight.metricSummary,
                  ),
                  const SizedBox(height: 14),
                ],

                // Recommended Action Box
                Text(
                  'RECOMMENDED ACTION',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryContainer,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight.suggestedAction.isNotEmpty
                              ? insight.suggestedAction
                              : 'Keep applying progressive overload for optimal fitness progress.',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppButton.primary(
                  label: 'APPLY INSIGHT',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    if (insights.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'AI FITNESS INSIGHTS',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14151B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.appOutlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyzing Performance Data',
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complete workouts to unlock personalized recommendations.',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  'AI FITNESS INSIGHTS',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Text(
              '${insights.length} Recommended',
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = insights[index];
              final categoryColor = _getCategoryColor(item.category);

              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 80)),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.85, end: 1.0),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () => _showInsightDetailModal(context, item),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14151B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            Icon(
                              _getInsightIcon(item.icon),
                              size: 18,
                              color: categoryColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          item.title,
                          style: AppTheme.headlineLgMobile.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Description
                        Text(
                          item.description,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Suggested Action Preview
                        if (item.suggestedAction.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: categoryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.suggestedAction,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: categoryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
