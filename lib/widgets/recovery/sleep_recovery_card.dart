import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/sleep_record.dart';
import '../../models/recovery_insight.dart';
import '../../providers/fitness_provider.dart';
import 'calculation_info_modal.dart';
import 'manual_sleep_logger_modal.dart';
import 'connect_wearable_modal.dart';

/// Primary "Sleep & Recovery" dashboard card replacing old gimmicky readiness/recovery percentage scores.
/// Shows transparent sleep telemetry, consistency, resting HR, HRV, and factual recovery status.
/// Displays a clean actionable empty state for fresh users.
class SleepRecoveryCard extends StatelessWidget {
  final SleepRecord? sleepRecord;
  final RecoveryInsight? recoveryInsight;

  const SleepRecoveryCard({super.key, this.sleepRecord, this.recoveryInsight});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final sleep = sleepRecord ?? provider.latestSleep;
        final insight = recoveryInsight ?? provider.recoveryInsight;
        final hasData = sleep != null && insight.hasSufficientData;

        return _Glass(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bedtime_rounded,
                      color: context.appPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SLEEP & RECOVERY',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.appPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData ? 'Last night' : 'Recovery Telemetry',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => CalculationInfoModal.show(context),
                    icon: const Icon(Icons.info_outline_rounded),
                    iconSize: 18,
                    color: context.appTextSecondary,
                    tooltip: 'How is this calculated?',
                    visualDensity: VisualDensity.compact,
                  ),
                  if (hasData)
                    IconButton(
                      onPressed: () => ManualSleepLoggerModal.show(context),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      iconSize: 20,
                      color: context.appPrimary,
                      tooltip: 'Log Sleep',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Body: Populated State vs. Fresh User Empty State
              if (!hasData)
                _buildEmptyState(context)
              else
                _buildPopulatedState(context, sleep, insight),
            ],
          ),
        );
      },
    );
  }

  // --- Fresh User Clean Empty State ---
  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appSurfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nightlight_round_outlined,
                  color: context.appPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No sleep data yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect a wearable or log your sleep to start tracking recovery.',
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
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ConnectWearableModal.show(context),
                icon: const Icon(Icons.watch_rounded, size: 16),
                label: const Text(
                  'CONNECT WEARABLE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appPrimary,
                  side: BorderSide(color: context.appPrimary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => ManualSleepLoggerModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'LOG SLEEP',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Populated State ---
  Widget _buildPopulatedState(
    BuildContext context,
    SleepRecord sleep,
    RecoveryInsight insight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Metrics Grid
        Row(
          children: [
            // Sleep Duration & Quality
            Expanded(
              child: _Glass.inner(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sleep',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.appTextSecondary,
                          ),
                        ),
                        Text(
                          sleep.quality.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: context.appPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sleep.formattedDuration,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sleep.formattedBedtime} → ${sleep.formattedWakeTime}',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sleep Consistency
            Expanded(
              child: _Glass.inner(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consistency',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sleep.consistency.label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schedule regularity',
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
        const SizedBox(height: 10),

        // Physiological Indicators (RHR & HRV if available)
        if (sleep.restingHeartRate != null || sleep.hrv != null)
          Row(
            children: [
              if (sleep.restingHeartRate != null)
                Expanded(
                  child: _Glass.inner(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: context.isDarkMode
                              ? const Color(0xFFF87171)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resting HR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.appTextSecondary,
                              ),
                            ),
                            Text(
                              '${sleep.restingHeartRate!.toStringAsFixed(0)} bpm',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (sleep.restingHeartRate != null && sleep.hrv != null)
                const SizedBox(width: 10),
              if (sleep.hrv != null)
                Expanded(
                  child: _Glass.inner(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monitor_heart_rounded,
                          size: 16,
                          color: context.isDarkMode
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HRV',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.appTextSecondary,
                              ),
                            ),
                            Text(
                              '${sleep.hrv!.toStringAsFixed(0)} ms',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),

        // Status Pill & Interpretation Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.appPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.appPrimary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(insight.status.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.appPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.appSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sleep.source.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Translucent card for the sleep section. [inner] is the flat tile used
/// inside the main card, so cards are not nested in cards.
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool inner;

  const _Glass({required this.child, required this.padding}) : inner = false;
  const _Glass.inner({required this.child, required this.padding})
    : inner = true;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(inner ? 14 : 20),
        color: inner
            ? (dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : context.appSurfaceVariant.withValues(alpha: 0.6))
            : null,
        gradient: inner
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : [Colors.white, Colors.white.withValues(alpha: 0.7)],
              ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: inner ? 0.08 : 0.12)
              : context.appOutlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }
}
