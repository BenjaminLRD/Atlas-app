import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/fitness_insight.dart';
import '../../models/nutrition_summary.dart';

/// Nutrition Insights Section powered by FitnessInsight rules
class NutritionInsightSection extends StatelessWidget {
  final NutritionSummary summary;

  const NutritionInsightSection({
    super.key,
    required this.summary,
  });

  List<FitnessInsight> _generateNutritionInsights() {
    final List<FitnessInsight> insights = [];
    final now = DateTime.now();

    // 1. Protein Target Insight
    if (summary.proteinGoalHitPercentage >= 80) {
      insights.add(
        FitnessInsight(
          id: 'ins_protein_high',
          title: 'Optimal Protein Muscle Recovery',
          description: 'You hit your protein target ${summary.proteinGoalHitPercentage.toStringAsFixed(0)}% of the time this week!',
          category: 'performance',
          priority: 'high',
          icon: 'fitness_center',
          createdAt: now,
          suggestedAction: 'Maintain post-workout protein timing',
        ),
      );
    } else {
      insights.add(
        FitnessInsight(
          id: 'ins_protein_boost',
          title: 'Protein Intake Boost Required',
          description: 'Average protein intake is ${summary.averageProtein.toStringAsFixed(0)}g/day. Increase lean protein source portions.',
          category: 'balance',
          priority: 'medium',
          icon: 'restaurant',
          createdAt: now,
          suggestedAction: 'Add +50g Chicken Breast to Dinner',
        ),
      );
    }

    // 2. Calorie Consistency Insight
    if (summary.calorieGoalConsistency >= 70) {
      insights.add(
        FitnessInsight(
          id: 'ins_cal_consistent',
          title: 'Consistent Calorie Balance',
          description: 'Your energy intake remained within target threshold ${summary.calorieGoalConsistency.toStringAsFixed(0)}% of days.',
          category: 'consistency',
          priority: 'medium',
          icon: 'speed',
          createdAt: now,
          suggestedAction: 'Keep up this steady meal cadence',
        ),
      );
    }

    // 3. Nutrition Logging Streak Insight
    if (summary.currentNutritionStreak > 0) {
      insights.add(
        FitnessInsight(
          id: 'ins_streak_active',
          title: '${summary.currentNutritionStreak} Day Logging Streak',
          description: 'Consistent tracking unlocks high accuracy analytics and habit mastery.',
          category: 'motivation',
          priority: 'low',
          icon: 'local_fire_department',
          createdAt: now,
          suggestedAction: 'Log your next meal to extend your streak',
        ),
      );
    }

    return insights;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final insights = _generateNutritionInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NUTRITION INSIGHTS',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryContainer,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'AI Engine Ready',
              style: AppTheme.bodySm.copyWith(
                fontSize: 10,
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: insights.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final insight = insights[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14151B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconData(insight.icon),
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insight.description,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                        if (insight.suggestedAction.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tip: ${insight.suggestedAction}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
