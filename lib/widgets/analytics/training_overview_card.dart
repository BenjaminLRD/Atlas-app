import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/progress_summary.dart';
import '../../widgets/common/app_button.dart';
import 'analytics_card.dart';

/// Bento-style grid displaying core training metrics: Lifetime Volume, Monthly Volume, Training Time, and Total Workouts.
class TrainingOverviewCard extends StatelessWidget {
  final ProgressSummary summary;

  const TrainingOverviewCard({
    super.key,
    required this.summary,
  });

  void _showDetailBottomSheet(
    BuildContext context, {
    required String title,
    required String iconText,
    required String lifetimeValue,
    required String weeklyValue,
    required String monthlyValue,
    required double growthPercent,
    required String trendSummary,
  }) {
    final isDark = context.isDarkMode;
    final isPositive = growthPercent >= 0;

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
                        Text(iconText, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
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
                const SizedBox(height: 16),

                // Details Rows
                _buildStatRow(context, 'Lifetime Value', lifetimeValue),
                const SizedBox(height: 12),
                _buildStatRow(context, 'Current Month', monthlyValue),
                const SizedBox(height: 12),
                _buildStatRow(context, 'Current Week', weeklyValue),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isPositive ? AppColors.primaryContainer : Colors.redAccent).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isPositive ? AppColors.primaryContainer : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trendSummary,
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
                  label: 'CLOSE',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAINING OVERVIEW',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            AnalyticsCard(
              title: 'Lifetime Volume',
              value: summary.totalVolume,
              unit: 'kg',
              icon: Icons.fitness_center_rounded,
              onTap: () => _showDetailBottomSheet(
                context,
                title: 'Lifetime Volume',
                iconText: '🏋',
                lifetimeValue: '${summary.totalVolume.toStringAsFixed(0)} kg',
                monthlyValue: '${summary.monthlyVolume.toStringAsFixed(0)} kg',
                weeklyValue: '${summary.weeklyVolume.toStringAsFixed(0)} kg',
                growthPercent: summary.weeklyVolumeChangePercent,
                trendSummary: '${summary.weeklyVolumeChangePercent >= 0 ? "Up" : "Down"} ${summary.weeklyVolumeChangePercent.abs()}% compared to last week.',
              ),
            ),
            AnalyticsCard(
              title: 'Monthly Volume',
              value: summary.monthlyVolume,
              unit: 'kg',
              icon: Icons.calendar_month_rounded,
              accentColor: AppColors.primary,
              onTap: () => _showDetailBottomSheet(
                context,
                title: 'Monthly Volume',
                iconText: '📅',
                lifetimeValue: '${summary.totalVolume.toStringAsFixed(0)} kg',
                monthlyValue: '${summary.monthlyVolume.toStringAsFixed(0)} kg',
                weeklyValue: '${summary.weeklyVolume.toStringAsFixed(0)} kg',
                growthPercent: summary.monthlyVolumeChangePercent,
                trendSummary: '${summary.monthlyVolumeChangePercent >= 0 ? "Up" : "Down"} ${summary.monthlyVolumeChangePercent.abs()}% compared to last month.',
              ),
            ),
            AnalyticsCard(
              title: 'Training Time',
              value: summary.totalTrainingMinutes.toDouble(),
              unit: 'mins',
              isInteger: true,
              icon: Icons.timer_outlined,
              accentColor: Colors.orangeAccent,
              onTap: () => _showDetailBottomSheet(
                context,
                title: 'Training Duration',
                iconText: '⏱',
                lifetimeValue: '${summary.totalTrainingMinutes} mins',
                monthlyValue: '${(summary.totalTrainingMinutes * 0.4).round()} mins',
                weeklyValue: '${(summary.totalTrainingMinutes * 0.15).round()} mins',
                growthPercent: 12.0,
                trendSummary: 'Maintaining consistent active time in sessions.',
              ),
            ),
            AnalyticsCard(
              title: 'Total Workouts',
              value: summary.totalWorkouts.toDouble(),
              unit: 'sessions',
              isInteger: true,
              icon: Icons.bolt_rounded,
              accentColor: Colors.lightBlueAccent,
              onTap: () => _showDetailBottomSheet(
                context,
                title: 'Total Workouts',
                iconText: '💪',
                lifetimeValue: '${summary.totalWorkouts} sessions',
                monthlyValue: '${summary.totalWorkouts} sessions this month',
                weeklyValue: '${summary.weeklyWorkoutChange} vs last week',
                growthPercent: summary.weeklyWorkoutChange.toDouble(),
                trendSummary: '${summary.weeklyWorkoutChange >= 0 ? "Plus" : "Minus"} ${summary.weeklyWorkoutChange.abs()} workouts vs last week.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
