import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/training_state.dart';
import 'app_card.dart';

/// Reusable UI widget displaying training readiness %, fatigue level, intensity recommendation, and narrative.
/// Displays clean empty state when no workouts or recovery telemetry exist.
class ReadinessCard extends StatelessWidget {
  final TrainingState? state;

  const ReadinessCard({super.key, this.state});

  @override
  Widget build(BuildContext context) {
    // A readiness score is shown only when sleep, HRV or heart rate backs it.
    final hasData = state != null && state!.isMeasured;
    final readiness = state?.readinessScore ?? 0;
    final fatigue = state?.fatigueScore ?? 0;
    final intensity = state?.recommendedIntensity ?? '';
    final narrative = state?.recommendation ?? '';

    final isDark = context.isDarkMode;
    final themeColor = hasData
        ? _getReadinessColor(readiness)
        : context.appTextSecondary;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: themeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Training Readiness',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          Text(
                            'Adaptive Intelligence Engine',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildIntensityChip(
                    context: context,
                    hasData: hasData,
                    intensity: intensity,
                    readinessScore: readiness,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Readiness Score',
                  value: hasData ? '$readiness%' : '-',
                  color: hasData ? themeColor : context.appTextSecondary,
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Fatigue Level',
                  value: hasData ? '$fatigue%' : '-',
                  color: hasData
                      ? (fatigue > 60
                            ? Colors.red
                            : (fatigue > 35 ? Colors.orange : Colors.green))
                      : context.appTextSecondary,
                  icon: Icons.battery_charging_full_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : context.appSurfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: themeColor.withValues(alpha: hasData ? 0.2 : 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: themeColor),
                const SizedBox(width: 10),
                Expanded(
                  child: hasData
                      ? Text(
                          narrative,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextPrimary,
                            height: 1.35,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No readiness data yet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Complete workouts and track recovery to see personalized insights.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityChip({
    required BuildContext context,
    required bool hasData,
    required String intensity,
    required int readinessScore,
  }) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.appOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '-',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
      );
    }

    Color color = AppColors.primaryContainer;
    String text = 'GOOD';

    if (readinessScore >= 80) {
      color = Colors.green;
      text = 'OPTIMAL';
    } else if (readinessScore >= 70) {
      color = AppColors.primaryContainer;
      text = 'GOOD';
    } else if (readinessScore >= 50) {
      color = Colors.orange;
      text = 'MODERATE';
    } else {
      color = Colors.red;
      text = 'REST';
    }

    switch (intensity.toLowerCase()) {
      case 'heavy_training':
        color = Colors.green;
        text = readinessScore >= 80 ? 'OPTIMAL' : 'GOOD';
        break;
      case 'moderate_training':
        color = AppColors.primaryContainer;
        text = 'GOOD';
        break;
      case 'recovery':
        color = Colors.orange;
        text = 'RECOVERY';
        break;
      case 'rest':
        color = Colors.red;
        text = 'REST';
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : context.appSurfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
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

  Color _getReadinessColor(int readiness) {
    if (readiness >= 80) return Colors.green;
    if (readiness >= 60) return AppColors.primaryContainer;
    if (readiness >= 40) return Colors.orange;
    return Colors.red;
  }
}
