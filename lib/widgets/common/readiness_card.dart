import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/training_state.dart';
import 'app_card.dart';

/// Reusable UI widget displaying training readiness %, fatigue level, intensity recommendation, and narrative.
class ReadinessCard extends StatelessWidget {
  final TrainingState? state;

  const ReadinessCard({
    super.key,
    this.state,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = state?.readinessScore ?? 80;
    final fatigue = state?.fatigueScore ?? 30;
    final intensity = state?.recommendedIntensity ?? 'moderate_training';
    final narrative = state?.recommendation ??
        'Optimal readiness! Your muscles and nervous system are fully recovered for heavy compound lifting.';

    final isDark = context.isDarkMode;

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
                      color: _getReadinessColor(readiness).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: _getReadinessColor(readiness),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training Readiness',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        'Adaptive Intelligence Engine',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildIntensityChip(intensity),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Readiness Score',
                  value: '$readiness%',
                  color: _getReadinessColor(readiness),
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Fatigue Level',
                  value: '$fatigue%',
                  color: fatigue > 60 ? Colors.red : (fatigue > 35 ? Colors.orange : Colors.green),
                  icon: Icons.battery_charging_full_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getReadinessColor(readiness).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _getReadinessColor(readiness),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    narrative,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityChip(String intensity) {
    Color color = AppColors.primaryContainer;
    String text = 'MODERATE';

    switch (intensity.toLowerCase()) {
      case 'heavy_training':
        color = Colors.green;
        text = 'HEAVY INTENSITY';
        break;
      case 'moderate_training':
        color = AppColors.primaryContainer;
        text = 'MODERATE';
        break;
      case 'recovery':
        color = Colors.orange;
        text = 'ACTIVE RECOVERY';
        break;
      case 'rest':
      default:
        color = Colors.red;
        text = 'REST DAY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
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
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
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

  Color _getReadinessColor(int readiness) {
    if (readiness >= 80) return Colors.green;
    if (readiness >= 60) return AppColors.primaryContainer;
    if (readiness >= 40) return Colors.orange;
    return Colors.red;
  }
}
