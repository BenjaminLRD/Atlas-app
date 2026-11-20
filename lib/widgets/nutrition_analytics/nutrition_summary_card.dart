import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/nutrition_summary.dart';

/// Premium Nutrition Summary Card displaying high-level calorie & streak analytics
class NutritionSummaryCard extends StatelessWidget {
  final NutritionSummary summary;

  const NutritionSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(
              alpha: isDark ? 0.08 : 0.04,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_rounded,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NUTRITION SUMMARY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryContainer,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${summary.currentNutritionStreak} Day Streak',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'TOTAL CONSUMED',
                  // A minimum when some day left out foods with no calories.
                  value:
                      '${summary.totalCaloriesConsumed.toStringAsFixed(0)}${summary.unknownCalorieDays > 0 ? '+' : ''}',
                  unit: 'kcal',
                  icon: Icons.electric_bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'DAILY AVERAGE',
                  value: summary.caloriesKnown
                      ? summary.averageDailyCalories.toStringAsFixed(0)
                      : '—',
                  unit: summary.unknownCalorieDays > 0 && summary.caloriesKnown
                      ? 'kcal / day (complete days)'
                      : 'kcal / day',
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required IconData icon,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primaryContainer),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 9,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A value that is not a plain number ("1500+" for a minimum, a dash
          // for unknown) is shown as it is: counting up to it would turn an
          // unknown into 0.
          if (double.tryParse(value.replaceAll('+', '')) == null)
            Text(
              value,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(
                begin: 0,
                end: double.parse(value.replaceAll('+', '')),
              ),
              builder: (context, val, _) {
                return Text(
                  '${val.toStringAsFixed(0)}${value.endsWith('+') ? '+' : ''}',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                );
              },
            ),
          Text(
            unit,
            style: AppTheme.bodySm.copyWith(
              fontSize: 10,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
