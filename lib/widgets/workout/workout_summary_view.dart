import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/exercise/muscle_map.dart';
import '../../services/workout_summary.dart';
import '../common/app_animation.dart';
import '../common/app_button.dart';

/// The post-workout achievement screen: what was done and what was earned, in
/// a structured set of tiles. It only shows what [WorkoutSummaryData] holds; a
/// value that is not known appears as a dash.
class WorkoutSummaryView extends StatelessWidget {
  final WorkoutSummaryData data;
  final VoidCallback onFinish;

  const WorkoutSummaryView({
    super.key,
    required this.data,
    required this.onFinish,
  });

  static const Color gold = Color(0xFFFFD700);
  static const Color flame = Color(0xFFFF6B3D);
  static const Color sky = Color(0xFF3B8CF5);
  static const Color mint = AppColors.primaryContainer;
  static const Color amber = Color(0xFFF2B33D);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String formatDate(DateTime d) =>
      '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

  static String formatClock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (d.inMinutes > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String formatVolume(double kg) {
    final whole = kg.round();
    final text = whole.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$text kg';
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final hasPr = d.personalRecords.isNotEmpty;
    final streak = d.streakDays;

    final topTiles = <Widget>[
      if (hasPr) _prTile(context),
      if (streak != null)
        _SummaryTile(
          key: const Key('summary_streak'),
          color: flame,
          icon: Icons.local_fire_department_rounded,
          label: 'STREAK',
          value: streak == 1 ? '1 day' : '$streak days',
          valueColor: flame,
        ),
    ];

    final avg = d.averageSetSeconds;
    final bottomTiles = <Widget>[
      if (avg != null)
        _SummaryTile(
          key: const Key('summary_avg_set'),
          color: sky,
          icon: Icons.timer_outlined,
          label: 'AVG SET TIME',
          value: formatDuration(Duration(seconds: avg.round())),
        ),
      if (d.xpEarned != null)
        _SummaryTile(
          key: const Key('summary_xp'),
          color: mint,
          icon: Icons.bolt_rounded,
          label: 'XP EARNED',
          value: '+${d.xpEarned}',
          valueColor: mint,
        ),
    ];

    return Scaffold(
      key: const Key('workout_summary'),
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AppAnimation.confettiParticles(
                isAnimating: true,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Well done, ',
                            style: TextStyle(color: gold),
                          ),
                          TextSpan(text: 'you’ve completed ${d.workoutName}.'),
                        ],
                      ),
                      key: const Key('summary_title'),
                      style: AppTheme.headlineLg.copyWith(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDate(d.completedAt),
                      key: const Key('summary_date'),
                      style: AppTheme.bodyMd.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (topTiles.isNotEmpty) ...[
                      _row(topTiles),
                      const SizedBox(height: 12),
                    ],
                    _timeTile(context),
                    const SizedBox(height: 12),
                    _row([
                      _SummaryTile(
                        key: const Key('summary_exercises'),
                        color: mint,
                        icon: Icons.fitness_center_rounded,
                        label: 'EXERCISES',
                        value: '${d.exercisesCompleted}/${d.exercisesTotal}',
                        caption: 'completed',
                      ),
                      _SummaryTile(
                        key: const Key('summary_sets'),
                        color: mint,
                        icon: Icons.repeat_rounded,
                        label: 'SETS',
                        value: '${d.setsCompleted}/${d.setsTotal}',
                        caption: 'completed',
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _row([
                      _SummaryTile(
                        key: const Key('summary_volume'),
                        color: amber,
                        icon: Icons.scale_rounded,
                        label: 'TOTAL VOLUME',
                        value: d.totalVolumeKg == null
                            ? '—'
                            : formatVolume(d.totalVolumeKg!),
                        caption: d.totalVolumeKg == null
                            ? 'no loaded sets'
                            : null,
                      ),
                      _SummaryTile(
                        key: const Key('summary_calories'),
                        color: flame,
                        icon: Icons.local_fire_department_outlined,
                        label: 'CALORIES',
                        value: d.caloriesEstimate == null
                            ? '—'
                            : '${d.caloriesEstimate} kcal',
                        caption: d.caloriesEstimate == null ? null : 'estimate',
                      ),
                    ]),
                    if (bottomTiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _row(bottomTiles),
                    ],
                    if (hasPr) ...[
                      const SizedBox(height: 20),
                      _prList(context),
                    ],
                    if (d.muscles.isComplete) ...[
                      const SizedBox(height: 20),
                      _muscles(context),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: AppButton.primary(
                key: const Key('summary_finish'),
                label: 'Finish',
                isPill: true,
                onPressed: onFinish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(List<Widget> tiles) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  Widget _prTile(BuildContext context) {
    final prs = data.personalRecords;
    final first = prs.first;
    final single = prs.length == 1;
    return _SummaryTile(
      key: const Key('summary_pr'),
      color: gold,
      icon: Icons.emoji_events_rounded,
      label: single ? '${first.exerciseName} PR'.toUpperCase() : 'NEW PRs',
      value: single ? first.valueText : '${prs.length} new',
      valueColor: gold,
      caption: single ? first.type : first.exerciseName,
    );
  }

  Widget _timeTile(BuildContext context) {
    final d = data;
    Widget clock(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
    return _TileShell(
      key: const Key('summary_time'),
      color: sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: sky),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WORKOUT TIME',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelCaps.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sky,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sky,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  formatDuration(d.duration),
                  key: const Key('summary_duration'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              clock('Start time', formatClock(d.startTime)),
              clock(
                'End time',
                d.endTime == null ? '—' : formatClock(d.endTime!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prList(BuildContext context) {
    return Column(
      key: const Key('summary_pr_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERSONAL RECORDS',
          style: AppTheme.labelCaps.copyWith(
            fontWeight: FontWeight.w900,
            color: gold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        for (final pr in data.personalRecords)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.exerciseName,
                        style: AppTheme.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        pr.type,
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pr.valueText,
                      style: AppTheme.bodyMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: gold,
                      ),
                    ),
                    if (pr.improvementPercent != null)
                      Text(
                        '+${pr.improvementPercent!.toStringAsFixed(1)}%',
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _muscles(BuildContext context) {
    final m = data.muscles;
    List<MuscleRegion> sorted(Set<MuscleRegion> s) =>
        s.toList()..sort((a, b) => a.index - b.index);
    Widget chip(String text, bool strong) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong
            ? mint.withValues(alpha: 0.18)
            : context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: strong ? mint : context.appOutlineVariant),
      ),
      child: Text(
        text,
        style: AppTheme.bodySm.copyWith(
          fontWeight: FontWeight.w700,
          color: strong ? mint : context.appTextSecondary,
        ),
      ),
    );
    return Column(
      key: const Key('summary_muscles'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MUSCLES WORKED',
          style: AppTheme.labelCaps.copyWith(
            fontWeight: FontWeight.w900,
            color: context.appTextPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in sorted(m.primary)) chip(r.label, true),
            for (final r in sorted(m.secondary)) chip(r.label, false),
            if (m.general) chip('Full body', true),
          ],
        ),
      ],
    );
  }
}

class _TileShell extends StatelessWidget {
  final Color color;
  final Widget child;

  const _TileShell({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDarkMode ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  const _SummaryTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 18),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: valueColor ?? context.appTextPrimary,
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
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
  }
}
