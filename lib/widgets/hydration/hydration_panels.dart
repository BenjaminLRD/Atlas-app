import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/hydration.dart';

const Color _water = Color(0xFF34D399);

BoxDecoration _panel(BuildContext context) => BoxDecoration(
  color: context.appSurfaceElevated,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: context.appOutlineVariant),
);

/// A bar from 0 to 100% of the target. It stops at full when the target is
/// passed; [over] then marks the extra.
class HydrationProgressBar extends StatelessWidget {
  const HydrationProgressBar({
    super.key,
    required this.progress,
    this.height = 10,
  });

  /// Actual progress, which may be above 1.0.
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: context.appOutlineVariant.withValues(alpha: 0.5),
          ),
          FractionallySizedBox(
            widthFactor: shown,
            child: Container(
              key: const Key('progress_fill'),
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: progress > 1
                      ? const [Color(0xFF34D399), Color(0xFF22D3EE)]
                      : const [Color(0xFF059669), Color(0xFF34D399)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today at a glance: amount, remaining, percentage, glass equivalents and the
/// progress bar.
class HydrationSummaryCard extends StatelessWidget {
  const HydrationSummaryCard({super.key, required this.day});

  final DayHydration day;

  @override
  Widget build(BuildContext context) {
    final goal = day.goalMl ?? 0;
    final ml = day.consumedMl;
    final glasses = GlassMath.glassesConsumed(ml);
    final left = GlassMath.glassesRemaining(ml, goal);
    final progress = goal > 0 ? ml / goal : 0.0;
    final pct = goal > 0 ? (ml * 100) ~/ goal : 0;
    final over = day.overMl ?? 0;
    final reached = goal > 0 && ml >= goal;

    Widget stat(Key k, String value, String label) => Expanded(
      child: Column(
        key: k,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    GlassMath.volumeLabel(ml),
                    key: const Key('today_consumed'),
                    style: AppTheme.displayMetrics.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ),
              Text(
                'of ${GlassMath.volumeLabel(goal)}',
                key: const Key('today_goal'),
                style: AppTheme.bodySm.copyWith(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reached
                ? (over > 0
                      ? 'Goal reached, ${GlassMath.volumeLabel(over)} over'
                      : 'Goal reached')
                : '${GlassMath.volumeLabel(day.remainingMl ?? goal)} to go',
            key: const Key('today_status'),
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: reached ? _water : context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          HydrationProgressBar(progress: progress),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(const Key('stat_percent'), '$pct%', 'of goal'),
              stat(
                const Key('stat_glasses'),
                GlassMath.glassLabel(glasses),
                'glasses drunk',
              ),
              stat(
                const Key('stat_glasses_left'),
                GlassMath.glassLabel(left),
                'glasses left',
              ),
              stat(
                const Key('stat_remaining'),
                GlassMath.volumeLabel(day.remainingMl ?? goal),
                'remaining',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The personalised target, how it was worked out, and a way to change it.
class HydrationGoalCard extends StatelessWidget {
  const HydrationGoalCard({
    super.key,
    required this.goal,
    required this.onAdjust,
    this.canAdjust = true,
  });

  final HydrationGoal goal;
  final VoidCallback onAdjust;
  final bool canAdjust;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: _water, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily goal',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Container(
                key: const Key('goal_basis'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _water.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  goal.basis.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _water,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            GlassMath.volumeLabel(goal.goalMl),
            key: const Key('goal_value'),
            style: AppTheme.displayMetrics.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            goal.explanation,
            key: const Key('goal_why'),
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              height: 1.35,
              color: context.appTextSecondary,
            ),
          ),
          if (goal.basis != HydrationGoalBasis.manual &&
              goal.activityMl > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Baseline ${goal.baselineMl} ml + activity ${goal.activityMl} ml',
              key: const Key('goal_breakdown'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'A general estimate, not medical advice. Needs vary with the '
            'person, the weather and what you eat.',
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
          if (canAdjust)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('goal_adjust'),
                onPressed: onAdjust,
                child: const Text('Adjust'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seven bars, Monday to Sunday, each against that day's own target.
class HydrationWeekChart extends StatelessWidget {
  const HydrationWeekChart({super.key, required this.week, this.onDayTap});

  final WeekHydration week;
  final ValueChanged<DayHydration>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final days = week.days;
    var top = 1000;
    for (final d in days) {
      top = math.max(top, math.max(d.totalMl ?? 0, d.goalMl ?? 0));
    }
    const chartH = 120.0;
    final total = week.totalKnownMl;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(total / 1000).toStringAsFixed(1)} L',
            key: const Key('week_total'),
            style: AppTheme.displayMetrics.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          Text(
            week.knownDays == 0
                ? 'No water recorded this week'
                : 'Total water this week · ${week.knownDays} of 7 days recorded',
            key: const Key('week_caption'),
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartH + MediaQuery.textScalerOf(context).scale(72),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _DayBar(
                      key: Key('week_day_${days[i].dayKey}'),
                      day: days[i],
                      top: top,
                      chartH: chartH,
                      showMonth: i == 0 || days[i].date.day == 1,
                      onTap: onDayTap == null ? null : () => onDayTap!(days[i]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A dash means nothing was recorded that day, which is not the same '
            'as drinking nothing.',
            style: AppTheme.bodySm.copyWith(
              fontSize: 10.5,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    super.key,
    required this.day,
    required this.top,
    required this.chartH,
    required this.showMonth,
    this.onTap,
  });

  final DayHydration day;
  final int top;
  final double chartH;
  final bool showMonth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final total = day.totalMl;
    final goal = day.goalMl;
    final h = total == null ? 0.0 : (total / top) * chartH;
    final goalY = goal == null ? null : (goal / top) * chartH;
    final met = total != null && goal != null && total >= goal;
    final unknown = day.status == HydrationDayStatus.noData;
    final color = met ? _water : _water.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: chartH,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (unknown)
                  Container(
                    key: const Key('bar_unknown'),
                    width: 16,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.appOutlineVariant),
                    ),
                    child: Text(
                      '–',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  )
                else
                  Container(
                    key: const Key('bar_fill'),
                    width: 16,
                    height: math.max(3.0, h),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                if (goalY != null)
                  Positioned(
                    bottom: goalY - 1,
                    child: Container(
                      key: const Key('bar_goal'),
                      width: 26,
                      height: 2,
                      color: context.appTextPrimary.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: day.isToday ? _water.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(8),
              border: day.isToday ? Border.all(color: _water) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('E').format(day.date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: day.isToday ? FontWeight.w900 : FontWeight.w600,
                    color: day.isToday ? _water : context.appTextSecondary,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    showMonth
                        ? DateFormat('d MMM').format(day.date)
                        : '${day.date.day}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: context.appTextSecondary,
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
}

/// Days with a record, today first, each with its total and its own target.
class HydrationHistoryList extends StatelessWidget {
  const HydrationHistoryList({
    super.key,
    required this.days,
    required this.onTap,
    required this.now,
  });

  final List<DayHydration> days;
  final ValueChanged<DayHydration> onTap;
  final DateTime now;

  static String dateLabel(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(
      d.year == now.year ? 'EEE d MMM' : 'EEE d MMM y',
    ).format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              key: Key('history_${d.dayKey}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(d),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: _panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          color: _water,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateLabel(d.date, now),
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        if (d.isSample)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              'SAMPLE',
                              key: Key('sample_${d.dayKey}'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ),
                        Text(
                          switch (d.status) {
                            HydrationDayStatus.noData => 'No data',
                            HydrationDayStatus.confirmedZero => '0 ml',
                            HydrationDayStatus.recorded =>
                              GlassMath.volumeLabel(d.consumedMl),
                          },
                          key: Key('history_total_${d.dayKey}'),
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (d.progress != null)
                      HydrationProgressBar(progress: d.progress!, height: 6),
                    const SizedBox(height: 6),
                    Text(
                      d.goal == null
                          ? 'Goal for this day not recorded'
                          : 'Goal ${GlassMath.volumeLabel(d.goal!.goalMl)}'
                                '${d.progress == null ? '' : ' · ${(d.totalMl! * 100) ~/ d.goalMl!}%'}',
                      key: Key('history_goal_${d.dayKey}'),
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
