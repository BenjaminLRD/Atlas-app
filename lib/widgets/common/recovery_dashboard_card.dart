import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recovery_state.dart';
import 'app_card.dart';

/// Reusable UI card displaying recovery score %, fatigue level, training status, and recommendation.
class RecoveryDashboardCard extends StatelessWidget {
  final RecoveryState? state;

  const RecoveryDashboardCard({
    super.key,
    this.state,
  });

  @override
  Widget build(BuildContext context) {
    final score = state?.recoveryScore ?? 82;
    final fatigue = state?.fatigueLevel ?? FatigueLevel.low;
    final rec = state?.recommendation ?? RecoveryRecommendation.trainNormal;
    final trend = state?.recoveryTrend ?? 'stable';

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
                      color: _getScoreColor(score).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.healing_rounded,
                      color: _getScoreColor(score),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery & Fatigue Intelligence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        'Trend: ${trend.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildRecommendationBadge(rec),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Recovery Score',
                  value: '$score%',
                  status: _getScoreLabel(score),
                  color: _getScoreColor(score),
                  icon: Icons.battery_saver_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Fatigue Level',
                  value: fatigue.name.toUpperCase(),
                  status: fatigue == FatigueLevel.low ? 'Optimal' : 'Elevated',
                  color: _getFatigueColor(fatigue),
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
    required String status,
    required Color color,
    required IconData icon,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                '$label • $status',
                style: TextStyle(
                  fontSize: 10,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBadge(RecoveryRecommendation rec) {
    Color color = AppColors.primaryContainer;
    String text = 'TRAIN NORMAL';

    switch (rec) {
      case RecoveryRecommendation.deloadWeek:
        color = Colors.purple;
        text = 'DELOAD WEEK';
        break;
      case RecoveryRecommendation.restDay:
        color = Colors.red;
        text = 'REST DAY';
        break;
      case RecoveryRecommendation.activeRecovery:
        color = Colors.orange;
        text = 'ACTIVE RECOVERY';
        break;
      case RecoveryRecommendation.reduceIntensity:
        color = Colors.blue;
        text = 'LIGHT INTENSITY';
        break;
      case RecoveryRecommendation.trainNormal:
        color = AppColors.primaryContainer;
        text = 'READY TO TRAIN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return AppColors.primaryContainer;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  Color _getFatigueColor(FatigueLevel fatigue) {
    switch (fatigue) {
      case FatigueLevel.critical:
        return Colors.red;
      case FatigueLevel.high:
        return Colors.orange;
      case FatigueLevel.moderate:
        return Colors.blue;
      case FatigueLevel.low:
        return Colors.green;
    }
  }
}
