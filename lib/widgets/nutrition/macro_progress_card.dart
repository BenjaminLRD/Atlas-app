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
        color: context.appCardBg,
        borderRadius: AppRadii.borderXl,
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [context.appCardShadow],
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
                    Icon(icon, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                currentText,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 15,
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
            borderRadius: BorderRadius.circular(999),
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
                      : context.appSurfaceContainerLow,
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
                currentText: '${log.dailyCaloriesLabel} kcal',
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
                currentText: log.totals.proteinText,
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
                currentText: log.totals.carbsText,
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
                currentText: log.totals.fatText,
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
