import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/health_metrics.dart';
import 'app_card.dart';

/// Reusable UI widget presenting daily integrated health metrics (Steps, Calories, Sleep, Recovery Score).
class HealthDashboardCard extends StatelessWidget {
  final HealthMetrics? metrics;
  final int recoveryScore;
  final VoidCallback? onSyncTap;

  const HealthDashboardCard({
    super.key,
    this.metrics,
    this.recoveryScore = 85,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    final steps = metrics?.steps ?? 8450;
    final calories = (metrics?.caloriesBurned ?? 420.0).toInt();
    final sleep = (metrics?.sleepHours ?? 7.5).toStringAsFixed(1);
    final activeMins = metrics?.activeMinutes ?? 42;

    return AppCard(
      padding: const EdgeInsets.all(16),
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
                      Icons.monitor_heart_rounded,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrated Health',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        'Synced from Health Provider',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildRecoveryBadge(context, recoveryScore),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  icon: Icons.directions_walk_rounded,
                  iconColor: Colors.blue,
                  label: 'Steps',
                  value: '$steps',
                  subtext: 'Goal 10,000',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  label: 'Calories',
                  value: '$calories kcal',
                  subtext: 'Active Burn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  icon: Icons.bedtime_rounded,
                  iconColor: Colors.indigo,
                  label: 'Sleep',
                  value: '$sleep hrs',
                  subtext: 'Rest Duration',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  icon: Icons.timer_rounded,
                  iconColor: Colors.teal,
                  label: 'Active Mins',
                  value: '$activeMins mins',
                  subtext: 'Daily Total',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryBadge(BuildContext context, int score) {
    Color color = Colors.green;
    String label = 'Optimal';
    if (score < 60) {
      color = Colors.red;
      label = 'Fatigued';
    } else if (score < 75) {
      color = Colors.orange;
      label = 'Moderate';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '$score/100',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
