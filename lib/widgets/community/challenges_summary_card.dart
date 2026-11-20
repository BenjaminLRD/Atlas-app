import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/atlas_challenge.dart';
import '../../screens/challenges_screen.dart';
import '../../services/challenges/atlas_challenge_service.dart';
import '../../services/challenges/challenge_progress.dart';
import 'atlas_challenge_card.dart';

/// A short view of your challenges for the Friends screen: how many are
/// active, the first one, and a way to the full list. It uses the same data
/// and layout as the Challenges tab, so nothing here is scripted differently.
class ChallengesSummaryCard extends StatefulWidget {
  const ChallengesSummaryCard({super.key});

  @override
  State<ChallengesSummaryCard> createState() => _ChallengesSummaryCardState();
}

class _ChallengesSummaryCardState extends State<ChallengesSummaryCard> {
  List<AtlasChallenge> _active = const [];
  late ChallengeInputs _inputs;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _inputs = ChallengeInputs.live();
    final service = AtlasChallengeService.instance;
    await service.refresh(_inputs);
    if (!mounted) return;
    setState(() {
      _active = service.active();
      _loaded = true;
    });
  }

  Future<void> _openAll() async {
    await ChallengesScreen.open(context);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      key: const Key('challenges_summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'YOUR CHALLENGES',
                style: AppTheme.headlineMd.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            TextButton(
              key: const Key('challenges_see_all'),
              onPressed: _openAll,
              child: Text(
                _active.isEmpty ? 'START ONE' : 'SEE ALL (${_active.length})',
              ),
            ),
          ],
        ),
        if (_active.isEmpty)
          Text(
            'No active challenges.',
            key: const Key('challenges_summary_empty'),
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          )
        else
          AtlasChallengeCard(
            challenge: _active.first,
            inputs: _inputs,
            onTap: _openAll,
          ),
      ],
    );
  }
}
