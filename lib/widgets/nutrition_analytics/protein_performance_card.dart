import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/nutrition_summary.dart';

/// Performance card highlighting protein goal consistency and average intake
class ProteinPerformanceCard extends StatelessWidget {
  final NutritionSummary summary;

  const ProteinPerformanceCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final hitPct = summary.proteinGoalHitPercentage.clamp(0.0, 100.0);
    final daysAchieved = ((hitPct / 100.0) * 7.0).round().clamp(0, 7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF64B5F6).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64B5F6).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 12,
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
                  const Icon(
                    Icons.fitness_center_rounded,
                    size: 18,
                    color: Color(0xFF64B5F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROTEIN PERFORMANCE',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64B5F6),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF64B5F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$daysAchieved / 7 days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64B5F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hitPct.toStringAsFixed(0)}%',
                    style: AppTheme.headlineLgMobile.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.appTextPrimary,
                    ),
                  ),
                  Text(
                    'Goal Success Rate',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.averageProtein.toStringAsFixed(0)}g avg',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64B5F6),
                    ),
                  ),
                  Text(
                    'Daily Average Intake',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: hitPct / 100.0),
              builder: (context, val, _) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
