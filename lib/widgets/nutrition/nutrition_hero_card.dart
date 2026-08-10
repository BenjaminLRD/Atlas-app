import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../providers/fitness_provider.dart';

/// Premium Hero Card for the Nutrition Dashboard consuming FitnessProvider.todayNutritionLog.
class NutritionHeroCard extends StatelessWidget {
  const NutritionHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;
    final log = provider.todayNutritionLog;

    final consumedCals = log.dailyCalories;
    final goalCals = log.calorieGoal;
    final remainingCals = (goalCals - consumedCals).clamp(0.0, 20000.0);
    final calProgress = log.calorieProgress;

    final consumedProtein = log.dailyProtein;
    final goalProtein = log.proteinGoal;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
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
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S NUTRITION",
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryContainer,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Daily Energy & Macros',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${remainingCals.toStringAsFixed(0)} kcal left',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Calorie Counter Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: consumedCals),
                        builder: (context, val, _) {
                          return Text(
                            val.toStringAsFixed(0),
                            style: AppTheme.headlineLgMobile.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: context.appTextPrimary,
                            ),
                          );
                        },
                      ),
                      Text(
                        ' / ${goalCals.toStringAsFixed(0)} kcal',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Target Daily Intake',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),

              // Protein Summary Pill
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROTEIN TARGET',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${consumedProtein.toStringAsFixed(0)}g / ${goalProtein.toStringAsFixed(0)}g',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Animated Calorie Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: calProgress),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryContainer,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
