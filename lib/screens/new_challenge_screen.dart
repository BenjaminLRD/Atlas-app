import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/atlas_challenge.dart';
import '../services/challenges/atlas_challenge_service.dart';
import '../services/challenges/challenge_progress.dart';
import '../services/community/sample_world.dart';
import '../widgets/community/atlas_challenge_card.dart';

/// Pick a preset or build a custom challenge, then choose whether it is just
/// you or you against a sample athlete.
class NewChallengeScreen extends StatefulWidget {
  /// Pre-selects a sample opponent (for example from their profile).
  final String? initialOpponentKey;

  /// Tests can say whether step readings exist instead of reading them.
  final bool? stepsAvailableOverride;

  const NewChallengeScreen({
    super.key,
    this.initialOpponentKey,
    this.stepsAvailableOverride,
  });

  /// Returns the created challenge id, or null if cancelled.
  static Future<String?> open(
    BuildContext context, {
    String? opponentKey,
    bool? stepsAvailable,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => NewChallengeScreen(
          initialOpponentKey: opponentKey,
          stepsAvailableOverride: stepsAvailable,
        ),
      ),
    );
  }

  @override
  State<NewChallengeScreen> createState() => _NewChallengeScreenState();
}

class _NewChallengeScreenState extends State<NewChallengeScreen> {
  static const _custom = 'custom';
  String _selected = ChallengePreset.presets.first.id;
  String? _opponent;
  ChallengeMetric _customMetric = ChallengeMetric.workouts;
  int _customDays = 7;
  final _targetController = TextEditingController(text: '3');
  String? _error;
  bool _saving = false;
  late final bool _stepsAvailable;

  @override
  void initState() {
    super.initState();
    _opponent = widget.initialOpponentKey;
    _stepsAvailable =
        widget.stepsAvailableOverride ?? ChallengeInputs.live().stepsAvailable;
    // Start on a preset that can actually be measured.
    if (!_stepsAvailable && ChallengePreset.presets.first.metric.needsSteps) {
      _selected = ChallengePreset.presets
          .firstWhere((p) => !p.metric.needsSteps)
          .id;
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final service = AtlasChallengeService.instance;
    String id;
    if (_selected == _custom) {
      final target = double.tryParse(_targetController.text.trim());
      if (target == null || target < 1) {
        setState(() {
          _error = 'Enter a target of at least 1.';
          _saving = false;
        });
        return;
      }
      final max = switch (_customMetric) {
        ChallengeMetric.workouts => 100.0,
        ChallengeMetric.minutes => 10000.0,
        ChallengeMetric.volumeKg => 1000000.0,
        ChallengeMetric.stepDays => _customDays.toDouble(),
      };
      if (target > max) {
        setState(() {
          _error = _customMetric == ChallengeMetric.stepDays
              ? 'Days at the goal cannot be more than the duration.'
              : 'That target is too high. The most is ${challengeNumber(max)}.';
          _saving = false;
        });
        return;
      }
      final c = await service.create(
        title:
            '${challengeNumber(target)} ${_customMetric.unit == 'days' ? 'step-goal days' : _customMetric.unit} in $_customDays days',
        metric: _customMetric,
        target: target,
        durationDays: _customDays,
        opponentKey: _opponent,
      );
      id = c.id;
    } else {
      final p = ChallengePreset.presets.firstWhere((p) => p.id == _selected);
      final c = await service.createFromPreset(p, opponentKey: _opponent);
      id = c.id;
    }
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final opponent = _opponent == null ? null : SampleWorld.byKey(_opponent!);
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'New challenge',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _label('CHOOSE A CHALLENGE'),
                for (final p in ChallengePreset.presets) _presetTile(p),
                _customTile(),
                const SizedBox(height: 16),
                _label('WHO IS IT AGAINST'),
                _opponentPicker(),
                const SizedBox(height: 8),
                Text(
                  'Challenges with real members need a server feature that is '
                  'not available yet, so you can challenge yourself or a '
                  'sample athlete. Sample athletes always accept and their '
                  'progress is scripted.',
                  key: const Key('real_challenges_note'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('create_challenge'),
                  onPressed: _saving ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    opponent == null
                        ? 'START CHALLENGE'
                        : 'CHALLENGE ${opponent.name.split(' ').first.toUpperCase()}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
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

  BoxDecoration _box(bool selected, {bool disabled = false}) => BoxDecoration(
    color: context.appSurfaceVariant.withValues(alpha: disabled ? 0.35 : 0.65),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: selected
          ? AppColors.primary
          : context.appOutlineVariant.withValues(alpha: 0.25),
      width: selected ? 1.5 : 1,
    ),
  );

  Widget _presetTile(ChallengePreset p) {
    final blocked = p.metric.needsSteps && !_stepsAvailable;
    final selected = _selected == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('preset_${p.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: blocked ? null : () => setState(() => _selected = p.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _box(selected, disabled: blocked),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: blocked
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                blocked
                    ? 'Unavailable: this phone has no step readings yet. '
                          'Allow activity access in Atlas.'
                    : '${p.durationDays} days · measured from ${p.metric.needsSteps ? 'step readings' : 'your logged workouts'}'
                          '${p.xpReward > 0 ? ' · ${p.xpReward} XP' : ''}',
                key: blocked ? const Key('preset_steps_unavailable') : null,
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customTile() {
    final selected = _selected == _custom;
    final metrics = [
      for (final m in ChallengeMetric.values)
        if (!m.needsSteps || _stepsAvailable) m,
    ];
    return InkWell(
      key: const Key('preset_custom'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selected = _custom),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _box(selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            Text(
              'Pick what to measure, the target and how long.',
              style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            ),
            if (selected) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ChallengeMetric>(
                key: const Key('custom_metric'),
                isExpanded: true,
                initialValue: metrics.contains(_customMetric)
                    ? _customMetric
                    : metrics.first,
                items: [
                  for (final m in metrics)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _customMetric = m!),
                decoration: const InputDecoration(labelText: 'Measure'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('custom_target'),
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _customMetric.needsSteps
                      ? 'Days at 10,000 steps'
                      : 'Target (${_customMetric.unit})',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [7, 14, 30])
                    ChoiceChip(
                      key: Key('custom_days_$d'),
                      label: Text('$d days'),
                      selected: _customDays == d,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _customDays == d
                            ? Colors.white
                            : context.appTextPrimary,
                      ),
                      onSelected: (_) => setState(() => _customDays = d),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('custom_error'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _opponentPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const Key('opponent_self'),
          label: const Text('Just me'),
          selected: _opponent == null,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: _opponent == null ? Colors.white : context.appTextPrimary,
          ),
          onSelected: (_) => setState(() => _opponent = null),
        ),
        for (final a in SampleWorld.athletes)
          ChoiceChip(
            key: Key('opponent_${a.key}'),
            label: Text('${a.name.split(' ').first} (sample)'),
            selected: _opponent == a.key,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: _opponent == a.key ? Colors.white : context.appTextPrimary,
            ),
            onSelected: (_) => setState(() => _opponent = a.key),
          ),
      ],
    );
  }
}
