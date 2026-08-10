import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/nutrition_log.dart';

/// Reusable Macro Progress Card & Macro Grid Widget
class MacroProgressCard extends StatelessWidget {
  final String title;
  final String currentText;
  final String targetText;
  final double progress;
  final IconData icon;
  final Color accentColor;

  const MacroProgressCard({
    super.key,
    required this.title,
    required this.currentText,
    required this.targetText,
    required this.progress,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentText = '${(clampedProgress * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
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
              Row(
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    title.toUpperCase(),
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                percentText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentText,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                ' / $targetText',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: clampedProgress),
              builder: (context, val, _) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Convenience grid displaying all 4 macronutrient progress cards using a NutritionLog instance.
  static Widget grid({
    required BuildContext context,
    required NutritionLog log,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MacroProgressCard(
                title: 'Calories',
                currentText: '${log.dailyCalories.toStringAsFixed(0)} kcal',
                targetText: '${log.calorieGoal.toStringAsFixed(0)} kcal',
                progress: log.calorieProgress,
                icon: Icons.local_fire_department_rounded,
                accentColor: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MacroProgressCard(
                title: 'Protein',
                currentText: '${log.dailyProtein.toStringAsFixed(0)}g',
                targetText: '${log.proteinGoal.toStringAsFixed(0)}g',
                progress: log.proteinProgress,
                icon: Icons.fitness_center_rounded,
                accentColor: const Color(0xFF64B5F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MacroProgressCard(
                title: 'Carbs',
                currentText: '${log.dailyCarbohydrates.toStringAsFixed(0)}g',
                targetText: '${log.carbohydrateGoal.toStringAsFixed(0)}g',
                progress: log.carbohydrateProgress,
                icon: Icons.grain_rounded,
                accentColor: const Color(0xFFFFB74D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MacroProgressCard(
                title: 'Fats',
                currentText: '${log.dailyFats.toStringAsFixed(0)}g',
                targetText: '${log.fatGoal.toStringAsFixed(0)}g',
                progress: log.fatProgress,
                icon: Icons.water_drop_rounded,
                accentColor: const Color(0xFFE57373),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
