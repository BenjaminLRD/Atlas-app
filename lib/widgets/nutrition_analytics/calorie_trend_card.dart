import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/nutrition_summary.dart';

/// 7-day calorie trend card with highest/lowest highlights
class CalorieTrendCard extends StatelessWidget {
  final NutritionSummary summary;

  const CalorieTrendCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final weekly = summary.weeklyCalories.length == 7
        ? summary.weeklyCalories
        : const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

    final maxVal = weekly.reduce((a, b) => a > b ? a : b);
    final minVal = weekly.reduce((a, b) => a < b ? a : b);
    final avgVal = summary.averageDailyCalories;

    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-DAY CALORIE TREND',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Avg: ${avgVal.toStringAsFixed(0)} kcal',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day Bar Graph
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final val = weekly[index];
                final heightFactor = maxVal > 0 ? (val / maxVal).clamp(0.1, 1.0) : 0.1;
                final isHighest = val > 0 && val == maxVal;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      val > 0 ? val.toStringAsFixed(0) : '-',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isHighest ? FontWeight.w900 : FontWeight.w600,
                        color: isHighest ? AppColors.primaryContainer : context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: 18,
                      height: 70 * heightFactor,
                      decoration: BoxDecoration(
                        color: isHighest
                            ? AppColors.primaryContainer
                            : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[index],
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 10,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // High / Low highlights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Highest: ${maxVal.toStringAsFixed(0)} kcal',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Lowest: ${minVal.toStringAsFixed(0)} kcal',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
