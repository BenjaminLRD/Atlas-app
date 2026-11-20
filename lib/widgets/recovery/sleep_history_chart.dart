import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/sleep_record.dart';
import '../common/app_card.dart';

/// 7-day interactive sleep history bar chart.
/// Tapping a day highlights that day's bedtime, wake time, duration, and quality.
class SleepHistoryChart extends StatefulWidget {
  final List<SleepRecord> sleepHistory;
  final double sleepGoalHours;

  const SleepHistoryChart({
    super.key,
    required this.sleepHistory,
    this.sleepGoalHours = 8.0,
  });

  @override
  State<SleepHistoryChart> createState() => _SleepHistoryChartState();
}

class _SleepHistoryChartState extends State<SleepHistoryChart> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant SleepHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.sleepHistory.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sleepHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    // Take up to trailing 7 days
    final displayRecords = widget.sleepHistory.take(7).toList();
    // Reverse so chronologically left-to-right (oldest to newest)
    final chronological = displayRecords.reversed.toList();
    final effectiveIndex = math.min(_selectedIndex, chronological.length - 1);
    final selectedRecord = chronological[effectiveIndex];

    final maxHours = chronological.fold<double>(
      widget.sleepGoalHours + 1.0,
      (max, r) => math.max(max, r.durationHours + 0.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 7-Day Bar Visualizer
        Container(
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(chronological.length, (index) {
              final record = chronological[index];
              final isSelected = index == effectiveIndex;
              final heightFraction = (record.durationHours / maxHours).clamp(
                0.1,
                1.0,
              );
              final meetsGoal =
                  record.durationHours >= (widget.sleepGoalHours - 0.5);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Duration label
                        Text(
                          '${record.durationHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Bar
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 80 * heightFraction,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (meetsGoal
                                          ? AppColors.primary.withValues(
                                              alpha: 0.5,
                                            )
                                          : const Color(
                                              0xFFF59E0B,
                                            ).withValues(alpha: 0.6)),
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Day label
                        Text(
                          record.dayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? context.appTextPrimary
                                : context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        // Selected Day Details Banner
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bedtime_outlined,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedRecord.dayLabel} • ${selectedRecord.formattedDuration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedRecord.formattedBedtime} → ${selectedRecord.formattedWakeTime}',
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
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.appSurfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${selectedRecord.quality.emoji} ${selectedRecord.quality.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  if (selectedRecord.restingHeartRate != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${selectedRecord.restingHeartRate!.toStringAsFixed(0)} bpm',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
