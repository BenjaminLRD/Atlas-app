import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/atlas_challenge.dart';
import '../../screens/challenge_detail_screen.dart';
import '../../screens/new_challenge_screen.dart';
import '../../services/challenges/atlas_challenge_service.dart';
import '../../services/challenges/challenge_progress.dart';
import 'atlas_challenge_card.dart';

/// Your challenges: invitations, Active and Past. Progress is counted from your
/// own workouts and step readings; sample opponents are labelled.
class ChallengesTab extends StatefulWidget {
  /// Tests can supply the data instead of reading the live records.
  final ChallengeInputs? inputsOverride;
  final bool? stepsAvailableOverride;

  const ChallengesTab({
    super.key,
    this.inputsOverride,
    this.stepsAvailableOverride,
  });

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  bool _past = false;
  bool _loaded = false;
  List<AtlasChallenge> _all = const [];
  late ChallengeInputs _inputs;

  @override
  void initState() {
    super.initState();
    _reload(seed: true);
  }

  Future<void> _reload({bool seed = false}) async {
    final service = AtlasChallengeService.instance;
    _inputs = widget.inputsOverride ?? ChallengeInputs.live();
    if (seed) await service.seedSampleInvitationsOnce(now: _inputs.now);
    await service.refresh(_inputs);
    if (!mounted) return;
    setState(() {
      _all = service.all();
      _loaded = true;
    });
  }

  Future<void> _new() async {
    await NewChallengeScreen.open(
      context,
      stepsAvailable: widget.stepsAvailableOverride,
    );
    await _reload();
  }

  Future<void> _open(AtlasChallenge c) async {
    await ChallengeDetailScreen.open(
      context,
      c.id,
      inputs: widget.inputsOverride,
    );
    await _reload();
  }

  Future<void> _answer(AtlasChallenge c, bool accept) async {
    final service = AtlasChallengeService.instance;
    if (accept) {
      await service.accept(c.id, now: _inputs.now);
    } else {
      await service.decline(c.id);
    }
    await _reload();
  }

  Widget _heading(String t, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: 8, top: 4),
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final invites = [
      for (final c in _all)
        if (c.status == AtlasChallengeStatus.invited) c,
    ];
    final active = [
      for (final c in _all)
        if (c.status == AtlasChallengeStatus.active) c,
    ];
    final past = [
      for (final c in _all)
        if (!c.isOpen) c,
    ];
    final shown = _past ? past : active;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        ElevatedButton.icon(
          key: const Key('new_challenge_button'),
          onPressed: _new,
          icon: const Icon(Icons.add_rounded),
          label: const Text('NEW CHALLENGE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (invites.isNotEmpty) ...[
          _heading('INVITATIONS', key: const Key('invitations_heading')),
          for (final c in invites)
            AtlasChallengeCard(
              key: Key('invite_${c.id}'),
              challenge: c,
              inputs: _inputs,
              onTap: () => _open(c),
              actions: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      key: Key('invite_accept_${c.id}'),
                      onPressed: () => _answer(c, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ACCEPT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('invite_decline_${c.id}'),
                      onPressed: () => _answer(c, false),
                      child: const Text('DECLINE'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('challenges_active_tab'),
              label: Text('Active (${active.length})'),
              selected: !_past,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: !_past ? Colors.white : context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() => _past = false),
            ),
            ChoiceChip(
              key: const Key('challenges_past_tab'),
              label: Text('Past (${past.length})'),
              selected: _past,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _past ? Colors.white : context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() => _past = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Container(
            key: Key(_past ? 'no_past_challenges' : 'no_active_challenges'),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.appSurfaceVariant.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 32,
                  color: context.appTextSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  _past ? 'No past challenges yet' : 'No active challenges',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _past
                      ? 'Completed, declined and expired challenges appear here.'
                      : 'Start one to track real progress from your workouts and steps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          for (final c in shown)
            AtlasChallengeCard(
              key: Key('challenge_${c.id}'),
              challenge: c,
              inputs: _inputs,
              onTap: () => _open(c),
            ),
        const SizedBox(height: 8),
        Text(
          'Challenges with real members need a server feature that is not '
          'available yet. Your progress is counted from your own workouts and '
          'steps; sample opponents are scripted and labelled.',
          key: const Key('challenges_footer'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.appTextSecondary),
        ),
      ],
    );
  }
}
