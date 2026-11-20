import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/atlas_challenge.dart';
import '../services/challenges/atlas_challenge_service.dart';
import '../services/challenges/challenge_progress.dart';
import '../services/community/sample_world.dart';
import '../widgets/community/atlas_challenge_card.dart';

/// One challenge in full: objective, dates, status, progress for you and (for
/// a sample opponent) their scripted progress, and what you can do next.
class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  /// Tests can supply the data instead of reading the live records.
  final ChallengeInputs? inputsOverride;

  const ChallengeDetailScreen({
    super.key,
    required this.challengeId,
    this.inputsOverride,
  });

  static Future<void> open(
    BuildContext context,
    String challengeId, {
    ChallengeInputs? inputs,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeDetailScreen(
          challengeId: challengeId,
          inputsOverride: inputs,
        ),
      ),
    );
  }

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  AtlasChallenge? _challenge;
  late ChallengeInputs _inputs;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _inputs = widget.inputsOverride ?? ChallengeInputs.live();
    await AtlasChallengeService.instance.refresh(_inputs);
    if (!mounted) return;
    setState(() {
      _challenge = AtlasChallengeService.instance.byId(widget.challengeId);
      _loaded = true;
    });
  }

  Future<void> _accept() async {
    await AtlasChallengeService.instance.accept(widget.challengeId);
    await _load();
  }

  Future<void> _decline() async {
    await AtlasChallengeService.instance.decline(widget.challengeId);
    await _load();
  }

  Future<void> _remove() async {
    await AtlasChallengeService.instance.remove(widget.challengeId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _challenge;
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Challenge',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : c == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This challenge no longer exists.',
                  key: const Key('challenge_missing'),
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: _body(c),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _panel({required Widget child, Key? key}) => Container(
    key: key,
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appSurfaceVariant.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: context.appOutlineVariant.withValues(alpha: 0.25),
      ),
    ),
    child: child,
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: AppTheme.labelCaps.copyWith(
        fontSize: 11,
        color: context.appTextSecondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );

  TextStyle _t(Color color, {double size = 13, FontWeight? w}) => TextStyle(
    fontSize: size,
    color: color,
    fontWeight: w ?? FontWeight.w600,
    height: 1.4,
  );

  String _measuredFrom(AtlasChallenge c) {
    switch (c.metric) {
      case ChallengeMetric.workouts:
        return 'Counted from the workouts you log inside the dates above.';
      case ChallengeMetric.minutes:
        return 'Counted from the duration of the workouts you log inside the '
            'dates above.';
      case ChallengeMetric.volumeKg:
        return 'Counted from the weight lifted in the workouts you log inside '
            'the dates above.';
      case ChallengeMetric.stepDays:
        return 'Counted from this phone\'s step readings: a day counts when '
            'it reaches ${challengeNumber(c.stepGoal)} steps. If there are no '
            'readings, progress is unavailable.';
    }
  }

  List<Widget> _body(AtlasChallenge c) {
    final sample = c.opponentKey == null
        ? null
        : SampleWorld.byKey(c.opponentKey!);
    final started = c.startDate != null;
    final you = ChallengeProgressCalculator.forYou(c, _inputs);
    final opp = sample == null || !started
        ? null
        : ChallengeProgressCalculator.scriptedOpponent(c, sample, _inputs.now);
    final yourValue = c.status == AtlasChallengeStatus.completed
        ? c.target
        : you.value;

    String? lead;
    if (c.status == AtlasChallengeStatus.active &&
        opp != null &&
        yourValue != null) {
      final d = yourValue - opp;
      lead = d == 0
          ? 'You are level with ${sample!.name.split(' ').first}.'
          : d > 0
          ? 'You are ahead by ${challengeNumber(d)} ${c.metric.unit}.'
          : 'You are behind by ${challengeNumber(-d)} ${c.metric.unit}.';
    }

    String? timeLeft;
    final end = c.endDate;
    if (c.status == AtlasChallengeStatus.active && end != null) {
      final days = end.difference(_inputs.now).inDays + 1;
      timeLeft = days <= 1 ? 'Last day' : '$days days left';
    } else if (c.status == AtlasChallengeStatus.invited &&
        c.inviteExpiresAt != null) {
      final days = c.inviteExpiresAt!.difference(_inputs.now).inDays + 1;
      timeLeft = 'Invitation expires in ${days < 1 ? 1 : days} days';
    }

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              c.title,
              key: const Key('detail_title'),
              style: _t(context.appTextPrimary, size: 20, w: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          ChallengeStatusChip(c.status),
        ],
      ),
      const SizedBox(height: 14),
      _panel(
        key: const Key('detail_objective'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('OBJECTIVE'),
            Text(
              c.objective,
              style: _t(context.appTextPrimary, size: 15, w: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Duration: ${c.durationDays} days',
              style: _t(context.appTextSecondary),
            ),
            Text(
              started
                  ? 'Dates: ${challengeRange(c)}'
                  : 'Dates: set when you accept',
              key: const Key('detail_dates'),
              style: _t(context.appTextSecondary),
            ),
            if (timeLeft != null)
              Text(
                timeLeft,
                key: const Key('detail_time_left'),
                style: _t(context.appTextSecondary),
              ),
            const SizedBox(height: 8),
            Text(
              _measuredFrom(c),
              style: _t(context.appTextSecondary, size: 12),
            ),
          ],
        ),
      ),
      if (started)
        _panel(
          key: const Key('detail_progress'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('PROGRESS'),
              ChallengeProgressRow(
                label: 'You',
                value: yourValue,
                target: c.target,
                unit: c.metric.unit,
                valueKey: const Key('detail_you_value'),
              ),
              if (!you.available && you.note != null) ...[
                const SizedBox(height: 6),
                Text(
                  you.note!,
                  key: const Key('detail_unavailable'),
                  style: _t(context.appTextSecondary, size: 12),
                ),
              ],
              if (opp != null) ...[
                const SizedBox(height: 12),
                ChallengeProgressRow(
                  label: sample!.name,
                  tag: const SamplePill(),
                  value: opp,
                  target: c.target,
                  unit: c.metric.unit,
                  barColor: context.appTextSecondary,
                  valueKey: const Key('detail_opp_value'),
                ),
              ],
              if (lead != null) ...[
                const SizedBox(height: 10),
                Text(
                  lead,
                  key: const Key('lead_line'),
                  style: _t(AppColors.primary, w: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      if (c.endNote != null && !c.isOpen)
        _panel(
          key: const Key('detail_end_note'),
          child: Text(c.endNote!, style: _t(context.appTextPrimary)),
        ),
      if (c.status == AtlasChallengeStatus.completed)
        _panel(
          key: const Key('detail_completed'),
          child: Text(
            c.completedAt == null
                ? 'Goal reached.'
                : 'Goal reached on ${challengeDate(c.completedAt!)}.',
            style: _t(AppColors.primary, size: 14, w: FontWeight.w800),
          ),
        ),
      if (c.xpReward > 0)
        _panel(
          key: const Key('detail_reward'),
          child: Text(
            c.status == AtlasChallengeStatus.completed
                ? (c.rewardPaid
                      ? '${c.xpReward} XP earned.'
                      : '${c.xpReward} XP will be added shortly.')
                : '${c.xpReward} XP when you reach the goal.',
            style: _t(context.appTextPrimary),
          ),
        ),
      if (sample != null)
        _panel(
          key: const Key('sample_note'),
          child: Text(
            '${sample.name} is a sample athlete. Their progress is scripted '
            'from their sample stats and is not a real person\'s activity. '
            'Sample athletes accept every challenge.',
            style: _t(context.appTextSecondary, size: 12),
          ),
        )
      else
        _panel(
          key: const Key('self_note'),
          child: Text(
            'A challenge against yourself. Progress comes only from your own '
            'logged activity. Challenges with real members need a server '
            'feature that is not available yet.',
            style: _t(context.appTextSecondary, size: 12),
          ),
        ),
      if (c.status == AtlasChallengeStatus.invited)
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const Key('detail_accept'),
                onPressed: _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('ACCEPT'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const Key('detail_decline'),
                onPressed: _decline,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('DECLINE'),
              ),
            ),
          ],
        )
      else
        OutlinedButton(
          key: const Key('remove_challenge'),
          onPressed: _remove,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(c.isOpen ? 'GIVE UP AND REMOVE' : 'REMOVE FROM HISTORY'),
        ),
    ];
  }
}
