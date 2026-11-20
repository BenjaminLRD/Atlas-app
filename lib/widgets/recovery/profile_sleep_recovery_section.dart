import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/sleep_record.dart';
import '../../models/recovery_insight.dart';
import '../../providers/fitness_provider.dart';
import '../common/app_card.dart';
import 'sleep_history_chart.dart';
import 'manual_sleep_logger_modal.dart';
import 'calculation_info_modal.dart';

/// Comprehensive Sleep & Recovery progress module integrated into the Profile Screen.
class ProfileSleepRecoverySection extends StatelessWidget {
  final List<SleepRecord>? history;
  final RecoveryInsight? insight;

  const ProfileSleepRecoverySection({
    super.key,
    this.history,
    this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final sleepList = history ?? provider.sleepHistory;
        final recoveryInsight = insight ?? provider.recoveryInsight;
        final hasData = sleepList.isNotEmpty;

        double avgSleepMinutes = 0;
        if (hasData) {
          final total = sleepList.take(7).fold<int>(
                0,
                (sum, r) => sum + r.durationMinutes,
              );
          avgSleepMinutes = total / (sleepList.take(7).length);
        }
        final avgHours = avgSleepMinutes ~/ 60;
        final avgMins = (avgSleepMinutes % 60).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SLEEP & RECOVERY',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '7-Day Recovery Trends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => CalculationInfoModal.show(context),
                  icon: const Icon(Icons.info_outline_rounded),
                  iconSize: 18,
                  tooltip: 'How is this calculated?',
                  visualDensity: VisualDensity.compact,
                ),
                TextButton(
                  onPressed: () => ManualSleepLoggerModal.show(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'LOG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!hasData)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bedtime_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No sleep history yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log your sleep or connect a wearable to visualize weekly trends.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTextSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Summary Bento Grid
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Avg',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${avgHours}h ${avgMins}m',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Goal: 8h 00m',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recoveryInsight.status.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sleepList.first.source.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive 7-Day Sleep History Bar Chart
              SleepHistoryChart(sleepHistory: sleepList),
              const SizedBox(height: 12),

              // Factual Interpretation Card
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recoveryInsight.interpretation,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextPrimary.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
