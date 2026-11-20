import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/cardio_activity_data.dart';
import '../../models/cardio_route.dart';
import '../../services/cardio/cardio_tracker.dart';

/// Icon for an activity kind.
IconData cardioIcon(CardioKind kind) => kind.isRunning
    ? Icons.directions_run_rounded
    : Icons.directions_bike_rounded;

/// A circular icon with a value and a caption beneath, in the style of the
/// reference cardio screen.
class CardioMetricTile extends StatelessWidget {
  const CardioMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
    this.accent,
    this.unavailable = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? unit;
  final Color? accent;

  /// True when the value could not be measured (shown as a dash).
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            unit == null || unavailable ? value : '$value $unit',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: unavailable
                  ? context.appTextSecondary
                  : context.appTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.bodySm.copyWith(
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// The big distance number with its caption.
class CardioDistanceHero extends StatelessWidget {
  const CardioDistanceHero({super.key, required this.distanceKm});

  /// Null when no distance was measured.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            distanceKm == null ? '–' : CardioFormat.distanceKm(distanceKm!),
            key: const Key('cardio_distance'),
            style: AppTheme.displayMetrics.copyWith(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: context.appTextPrimary,
            ),
          ),
        ),
        Text(
          'Distance (km)',
          style: AppTheme.bodySm.copyWith(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// The saved-activity statistics in a rounded panel: pace or speed, duration
/// and calories. Used by the detail screen and the post card.
class CardioStatsPanel extends StatelessWidget {
  const CardioStatsPanel({super.key, required this.data});

  final CardioActivityData data;

  @override
  Widget build(BuildContext context) {
    final kind = data.kind;
    final rate = kind.isRunning
        ? CardioFormat.pace(data.avgPaceSecPerKm)
        : CardioFormat.speed(data.avgSpeedKmh);
    final rateUnit = kind.isRunning ? '/km' : 'km/h';
    final rateMissing = kind.isRunning
        ? data.avgPaceSecPerKm == null
        : data.avgSpeedKmh == null;
    final cal = data.calories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appOutlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CardioMetricTile(
              key: const Key('stat_rate'),
              icon: kind.isRunning ? Icons.speed_rounded : Icons.bolt_rounded,
              value: rate,
              unit: rateUnit,
              label: kind.isRunning ? 'Avg pace' : 'Avg speed',
              unavailable: rateMissing,
            ),
          ),
          Expanded(
            child: CardioMetricTile(
              key: const Key('stat_duration'),
              icon: Icons.timer_outlined,
              value: data.durationSeconds == null
                  ? '–'
                  : CardioFormat.duration(data.durationSeconds!),
              label: 'Duration',
              unavailable: data.durationSeconds == null,
            ),
          ),
          Expanded(
            child: CardioMetricTile(
              key: const Key('stat_calories'),
              icon: Icons.local_fire_department_rounded,
              accent: const Color(0xFFF59E0B),
              value: CardioFormat.calories(cal),
              unit: 'kcal',
              label: cal == null
                  ? 'Calories n/a'
                  : (data.caloriesEstimated ? 'Calories (est.)' : 'Calories'),
              unavailable: cal == null,
            ),
          ),
        ],
      ),
    );
  }
}
