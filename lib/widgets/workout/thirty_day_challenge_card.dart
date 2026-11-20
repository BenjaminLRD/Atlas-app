import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/challenges/thirty_day_challenge.dart';

/// The 30-day challenge at the top of the Workouts page: the title, "Day 12 of
/// 30", thirty circles (filled for days with a completed workout, a ring for
/// today, dark for the rest) and the share completed.
///
/// With no challenge it offers to start one instead of pretending there is one.
class ThirtyDayChallengeCard extends StatelessWidget {
  const ThirtyDayChallengeCard({
    super.key,
    required this.view,
    this.onAccept,
    this.accepting = false,
  });

  /// Null when the athlete has not accepted a 30-day challenge.
  final ThirtyDayView? view;
  final VoidCallback? onAccept;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final v = view;
    return Container(
      key: const Key('challenge_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? const Color(0xFF14181B)
            : context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appOutlineVariant),
      ),
      child: v == null ? _empty(context) : _tracker(context, v),
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '30-DAY CHALLENGE',
          key: const Key('challenge_title'),
          style: AppTheme.headlineMd.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.05,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You have not started a 30-day challenge. Accept one and each day you '
          'complete a workout fills a circle.',
          key: const Key('challenge_empty'),
          style: AppTheme.bodySm.copyWith(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('challenge_accept'),
            onPressed: accepting ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            child: Text(accepting ? 'Starting…' : 'Start the 30-day challenge'),
          ),
        ),
      ],
    );
  }

  Widget _tracker(BuildContext context, ThirtyDayView v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                v.title.toUpperCase(),
                key: const Key('challenge_title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (v.isSample)
              Container(
                key: const Key('challenge_sample_badge'),
                margin: const EdgeInsets.only(left: 8, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appTextSecondary),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'SAMPLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          v.ended
              ? 'Challenge over · ${v.completedDays} of ${v.totalDays} days'
              : 'Day ${v.dayNumber} of ${v.totalDays}',
          key: const Key('challenge_day'),
          style: AppTheme.bodySm.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _Dots(days: v.days),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${v.completedDays} workout day${v.completedDays == 1 ? '' : 's'} done',
                key: const Key('challenge_done'),
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ),
            Text(
              '${v.percent}%',
              key: const Key('challenge_percent'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v.percent / 100),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) => LinearProgressIndicator(
              key: const Key('challenge_bar'),
              value: value,
              minHeight: 5,
              backgroundColor: context.appOutlineVariant.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        if (v.isSample)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Sample progress for the demo. Nothing here is saved to an account.',
              key: const Key('challenge_sample_note'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 10.5,
                color: context.appTextSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.days});

  final List<ChallengeDay> days;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
        final cols = w >= 340 ? 10 : 8;
        const gap = 6.0;
        // Alternate rows shift by half a circle, like the reference.
        final d = ((w - gap * (cols - 1)) / (cols + 0.5)).floorToDouble();
        final rows = (days.length / cols).ceil();
        return Column(
          key: const Key('challenge_dots'),
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              Padding(
                padding: EdgeInsets.only(left: r.isOdd ? d / 2 : 0),
                child: Row(
                  children: [
                    for (
                      var i = r * cols;
                      i < (r + 1) * cols && i < days.length;
                      i++
                    ) ...[
                      if (i > r * cols) const SizedBox(width: gap),
                      _Dot(day: days[i], size: d),
                    ],
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

class _Dot extends StatelessWidget {
  const _Dot({required this.day, required this.size});

  final ChallengeDay day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final Color fill;
    Color border;
    if (day.done) {
      fill = AppColors.primary;
      border = AppColors.primary;
    } else if (day.isToday) {
      fill = AppColors.primary.withValues(alpha: 0.12);
      border = AppColors.primary;
    } else if (day.missed) {
      fill = dark ? const Color(0xFF1F2428) : const Color(0xFFE3E8EB);
      border = context.appOutlineVariant;
    } else {
      fill = dark ? const Color(0xFF0E1113) : const Color(0xFFF0F3F5);
      border = context.appOutlineVariant.withValues(alpha: 0.35);
    }
    final state = day.done
        ? 'completed'
        : (day.isToday ? 'today' : (day.missed ? 'missed' : 'upcoming'));
    return Semantics(
      label: 'Day ${day.number}, $state',
      child: AnimatedContainer(
        key: Key('day_${day.number}_$state'),
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border, width: day.isToday ? 2 : 1),
          boxShadow: day.isToday
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${day.number}',
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: day.done
                    ? Colors.black
                    : (day.isToday
                          ? AppColors.primary
                          : context.appTextSecondary.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
