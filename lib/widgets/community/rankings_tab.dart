import 'package:flutter/material.dart';
import '../../data/local_storage.dart';
import '../../app_theme.dart';
import '../../models/workout_history.dart';
import '../../providers/fitness_provider.dart';
import '../../screens/athlete_profile_screen.dart';
import '../../services/community/sample_leaderboard.dart';
import '../../services/community/weekly_stats.dart';
import '../../services/steps/step_counter_service.dart';
import '../../services/steps/step_models.dart';
import 'community_avatar_helper.dart';

/// Rankings with two separate tabs.
///
/// * Real: only your own recorded week (workouts, minutes, volume, streak and
///   steps) against last week. There is no member leaderboard because nothing
///   shares other members' activity yet, and none is invented.
/// * Sample: a demo leaderboard of the 11 sample athletes, built from their
///   scripted stats and always labelled as sample.
class RankingsTab extends StatefulWidget {
  /// Tests can supply the week instead of reading the live data.
  final MyWeekly? weeklyOverride;

  /// Opens on the Sample tab (for example in Showcase Mode).
  final bool startOnSample;

  const RankingsTab({
    super.key,
    this.weeklyOverride,
    this.startOnSample = false,
  });

  @override
  State<RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<RankingsTab> {
  late bool _sample = widget.startOnSample;
  SampleTimeframe _timeframe = SampleTimeframe.week;
  SampleCategory _category = SampleCategory.workouts;

  MyWeekly _liveWeek() {
    final fp = FitnessProvider.instance;
    final List<WorkoutHistory> history = fp.workoutHistory;
    List<DayStepTotal> steps;
    try {
      steps = StepCounterService.instance.daysBack(14);
    } catch (_) {
      steps = const [];
    }
    return WeeklyStats.build(
      history: history,
      streakDays: history.isEmpty ? null : fp.workoutStreak,
      stepDays: steps,
      // Showcase Mode never reads the athlete's own cardio sessions.
      cardio: LocalStorage.isShowcaseModeEnabled()
          ? const []
          : LocalStorage.getCardioSessions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Row(
          children: [
            _segment('Real', !_sample, const Key('rankings_real_tab'), () {
              setState(() => _sample = false);
            }),
            const SizedBox(width: 8),
            _segment('Sample', _sample, const Key('rankings_sample_tab'), () {
              setState(() => _sample = true);
            }),
          ],
        ),
        const SizedBox(height: 12),
        if (_sample) ..._sampleBoard() else ..._realWeek(),
      ],
    );
  }

  Widget _segment(String label, bool on, Key key, VoidCallback onTap) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: on,
      selectedColor: AppColors.primary,
      backgroundColor: context.appSurfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
        color: on ? Colors.white : context.appTextPrimary,
      ),
      onSelected: (_) => onTap(),
    );
  }

  // ------------------------------------------------------------- real
  List<Widget> _realWeek() {
    final body = widget.weeklyOverride != null
        ? _realBody(widget.weeklyOverride!)
        : ListenableBuilder(
            listenable: Listenable.merge([
              FitnessProvider.instance,
              StepCounterService.instance,
            ]),
            builder: (_, _) => _realBody(_liveWeek()),
          );
    return [body];
  }

  Widget _realBody(MyWeekly w) {
    String n(num? v) => v == null ? '--' : _group(v);
    final c = w.current;
    final p = w.previous;
    String delta(num? a, num? b) {
      if (a == null || b == null) return '';
      final d = a - b;
      if (d == 0) return 'same';
      return d > 0 ? '+${_group(d)}' : '-${_group(d.abs())}';
    }

    Color deltaColor(num? a, num? b) {
      if (a == null || b == null || a == b) return context.appTextSecondary;
      return a > b ? AppColors.primary : context.appTextSecondary;
    }

    Widget compare(String label, num? prev, num? cur, {String unit = ''}) {
      final d = delta(cur, prev);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: _body(context.appTextPrimary))),
            Text(
              '${n(prev)}$unit  →  ',
              style: _body(context.appTextSecondary),
            ),
            Text(
              '${n(cur)}$unit',
              style: _body(context.appTextPrimary, weight: FontWeight.w800),
            ),
            if (d.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                d,
                style: _body(deltaColor(cur, prev), weight: FontWeight.w800),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          key: const Key('your_week_card'),
          borderColor: AppColors.primary.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('YOUR WEEK  ·  FROM YOUR OWN LOG'),
              const SizedBox(height: 4),
              Text(
                _weekRange(c.start),
                style: _body(context.appTextSecondary, size: 11),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat('wk_workouts', n(c.workouts), 'workouts'),
                  const SizedBox(width: 8),
                  _stat('wk_minutes', n(c.minutes), 'minutes'),
                  const SizedBox(width: 8),
                  _stat(
                    'wk_volume',
                    c.volumeKg == null ? '--' : _group(c.volumeKg!),
                    'kg lifted',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat('wk_streak', n(w.streakDays), 'day streak'),
                  const SizedBox(width: 8),
                  _stat('wk_steps', n(c.avgDailySteps), 'steps / day'),
                  const SizedBox(width: 8),
                  _stat(
                    'wk_cardio_km',
                    c.cardioKm == null ? '--' : c.cardioKm!.toStringAsFixed(1),
                    'km run & ride',
                  ),
                ],
              ),
              if (!w.hasAnyWorkouts) ...[
                const SizedBox(height: 10),
                Text(
                  'Log a workout and your week appears here.',
                  key: const Key('no_history_note'),
                  style: _body(context.appTextSecondary, size: 12),
                ),
              ] else if ((c.workouts ?? 0) == 0) ...[
                const SizedBox(height: 10),
                Text(
                  'No workouts logged yet this week.',
                  key: const Key('empty_week_note'),
                  style: _body(context.appTextSecondary, size: 12),
                ),
              ],
              if (c.avgDailySteps == null) ...[
                const SizedBox(height: 6),
                Text(
                  'Steps unavailable: no step readings this week. Allow '
                  'activity access in Atlas to count steps.',
                  key: const Key('steps_unavailable'),
                  style: _body(context.appTextSecondary, size: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const Key('vs_last_week'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('VS LAST WEEK'),
              const SizedBox(height: 6),
              compare('Workouts', p.workouts, c.workouts),
              compare('Minutes', p.minutes, c.minutes, unit: ' min'),
              compare('Steps / day', p.avgDailySteps, c.avgDailySteps),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          key: const Key('no_member_leaderboard'),
          child: Column(
            children: [
              Icon(
                Icons.groups_rounded,
                size: 28,
                color: context.appTextSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                'No member leaderboard yet',
                textAlign: TextAlign.center,
                style: _body(
                  context.appTextPrimary,
                  size: 15,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rankings between members need weekly totals to be shared '
                'with Atlas, which is not available yet. Your totals stay on '
                'this device. Switch to Sample to see a demo leaderboard.',
                textAlign: TextAlign.center,
                style: _body(context.appTextSecondary, size: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String key, String value, String label) {
    return Expanded(
      child: Container(
        key: Key(key),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: context.appSurfaceVariant.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: _body(
                context.appTextPrimary,
                size: 17,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _body(context.appTextSecondary, size: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _weekRange(DateTime start) {
    const m = [
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
    final end = start.add(const Duration(days: 6));
    return 'Monday ${start.day} ${m[start.month - 1]} to '
        'Sunday ${end.day} ${m[end.month - 1]}';
  }

  // ----------------------------------------------------------- sample
  List<Widget> _sampleBoard() {
    final categories = SampleLeaderboard.categoriesFor(_timeframe);
    final category = categories.contains(_category)
        ? _category
        : categories.first;
    final rows = SampleLeaderboard.rank(category, _timeframe);
    final podium = rows.take(3).toList();
    final rest = rows.skip(3).toList();

    return [
      _panel(
        key: const Key('sample_board_banner'),
        child: Row(
          children: [
            _samplePill(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Demo leaderboard of 11 sample athletes. Scripted figures, '
                'not real members.',
                style: _body(context.appTextSecondary, size: 12),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in SampleTimeframe.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('timeframe_${t.name}'),
                  label: Text(t.label),
                  selected: t == _timeframe,
                  selectedColor: AppColors.primary,
                  backgroundColor: context.appSurfaceVariant,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: t == _timeframe
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: t == _timeframe
                        ? Colors.white
                        : context.appTextPrimary,
                  ),
                  onSelected: (_) => setState(() => _timeframe = t),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('category_${c.name}'),
                  label: Text(c.label),
                  selected: c == category,
                  selectedColor: AppColors.primary,
                  backgroundColor: context.appSurfaceVariant,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: c == category
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: c == category
                        ? Colors.white
                        : context.appTextPrimary,
                  ),
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _podium(podium[1], 40)),
          Expanded(child: _podium(podium[0], 50)),
          Expanded(child: _podium(podium[2], 40)),
        ],
      ),
      const SizedBox(height: 14),
      _panel(child: Column(children: [for (final r in rest) _row(r)])),
      const SizedBox(height: 12),
      Text(
        'Tap an athlete to open their profile. Your own stats are not part of '
        'this board.',
        textAlign: TextAlign.center,
        key: const Key('sample_board_footer'),
        style: _body(context.appTextSecondary, size: 11),
      ),
    ];
  }

  void _open(SampleRankRow r) {
    AthleteProfileScreen.open(
      context,
      userId: r.athlete.id,
      name: r.athlete.name,
      avatarUrl: r.athlete.avatar,
      rank: r.athlete.rank,
    );
  }

  Widget _podium(SampleRankRow r, double avatar) {
    final first = r.rank == 1;
    return GestureDetector(
      key: Key('podium_${r.rank}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${r.rank}',
            style: _body(
              first ? AppColors.primary : context.appTextSecondary,
              size: 14,
              weight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          CommunityAvatarHelper.buildAvatar(
            userId: r.athlete.id,
            userName: r.athlete.name,
            avatarUrl: r.athlete.avatar,
            radius: avatar / 2 + 6,
            borderWidth: first ? 2.5 : 1.5,
            borderColor: first ? AppColors.primary : null,
          ),
          const SizedBox(height: 6),
          Text(
            r.athlete.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(
              context.appTextPrimary,
              size: 12,
              weight: FontWeight.w800,
            ),
          ),
          Text(
            r.valueLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(context.appTextSecondary, size: 11),
          ),
        ],
      ),
    );
  }

  Widget _row(SampleRankRow r) {
    return InkWell(
      key: Key('sample_rank_${r.athlete.key}'),
      onTap: () => _open(r),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${r.rank}',
                style: _body(context.appTextSecondary, weight: FontWeight.w800),
              ),
            ),
            CommunityAvatarHelper.buildAvatar(
              userId: r.athlete.id,
              userName: r.athlete.name,
              avatarUrl: r.athlete.avatar,
              radius: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r.athlete.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(context.appTextPrimary, weight: FontWeight.w700),
              ),
            ),
            Text(
              r.valueLabel,
              style: _body(context.appTextPrimary, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- helpers
  Widget _samplePill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: context.appTextSecondary),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'SAMPLE',
      style: _body(context.appTextSecondary, size: 10, weight: FontWeight.w800),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: AppTheme.labelCaps.copyWith(
      fontSize: 11,
      color: context.appTextSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    ),
  );

  TextStyle _body(Color color, {double size = 13, FontWeight? weight}) =>
      AppTheme.bodySm.copyWith(
        color: color,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
      );

  Widget _panel({required Widget child, Key? key, Color? borderColor}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              borderColor ?? context.appOutlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }

  static String _group(num v) {
    final s = v.round().toString();
    final neg = s.startsWith('-');
    final digits = neg ? s.substring(1) : s;
    final b = StringBuffer(neg ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }
}
