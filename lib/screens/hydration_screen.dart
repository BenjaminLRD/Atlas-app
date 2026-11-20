import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/hydration.dart';
import '../providers/fitness_provider.dart';
import '../services/hydration/hydration_goal_calculator.dart';
import '../services/hydration/hydration_service.dart';
import '../widgets/hydration/glass_tracker.dart';
import '../widgets/hydration/hydration_panels.dart';

/// The Hydration dashboard: today's glasses, the daily summary and target, the
/// week, and the history. Works the same for real accounts and Showcase Mode;
/// the [HydrationService] decides which store is used.
class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key, this.service});

  /// Injected by tests.
  final HydrationService? service;

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  late final HydrationService _svc =
      widget.service ?? HydrationService.instance;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_changed);
    FitnessProvider.instance.addListener(_activityChanged);
    _svc.refreshTodayGoal();
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_activityChanged);
    _svc.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// A finished workout or ride changes today's target, once per activity.
  void _activityChanged() => _svc.refreshTodayGoal();

  /// A short lockout so a double tap cannot record a drink twice.
  bool _allowTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < const Duration(milliseconds: 400)) {
      return false;
    }
    _lastTap = now;
    return true;
  }

  Future<void> _addGlasses(int n) async {
    if (!_allowTap()) return;
    await _svc.log(hydrationGlassMl * n);
  }

  Future<void> _custom() async {
    final ml = await _askNumber(
      title: 'Add water',
      label: 'Amount (ml)',
      hint: 'e.g. 330',
      min: 1,
      max: HydrationService.maxEntryMl,
    );
    if (ml != null) await _svc.log(ml);
  }

  Future<int?> _askNumber({
    required String title,
    required String label,
    required String hint,
    required int min,
    required int max,
    int? initial,
  }) {
    final ctrl = TextEditingController(text: initial?.toString() ?? '');
    String? error;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: TextField(
            key: const Key('amount_field'),
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('amount_ok'),
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                if (v == null || v < min || v > max) {
                  setLocal(
                    () => error = 'Enter a whole number from $min to $max',
                  );
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustGoal() async {
    final current = _svc.currentGoal();
    final ml = await _askNumber(
      title: 'Daily goal',
      label: 'Goal (ml)',
      hint: 'e.g. ${current.goalMl}',
      min: HydrationGoalCalculator.minManualMl,
      max: HydrationGoalCalculator.maxManualMl,
      initial: current.goalMl,
    );
    if (ml != null) await _svc.setManualGoal(ml);
  }

  void _openDay(DayHydration d) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _DaySheet(service: _svc, dayKey: d.dayKey, ask: _askNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _svc.today;
    final goal = today.goal ?? _svc.currentGoal();
    final week = _svc.week();
    final history = _svc.history(limit: _showAllHistory ? 90 : 7);
    final now = DateTime.now();
    final loggingEntries = today.entries.reversed.toList();

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appTextPrimary),
        title: Text(
          'Hydration',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (_svc.isSample)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'SAMPLE DATA: Showcase Mode shows demonstration hydration for '
                  'the sample athlete. Nothing here is saved to a real account.',
                  key: const Key('sample_note'),
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appOutlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    '${GlassMath.glassLabel(GlassMath.glassesConsumed(today.consumedMl))}'
                    ' of ${GlassMath.totalGlasses(goal.goalMl)} glasses',
                    key: const Key('glasses_headline'),
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Each glass is $hydrationGlassMl ml',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTracker(
                    consumedMl: today.consumedMl,
                    goalMl: goal.goalMl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            HydrationSummaryCard(day: today),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('add_glass'),
                    onPressed: () => _addGlasses(1),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('1 glass'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('add_two_glasses'),
                    onPressed: () => _addGlasses(2),
                    child: const Text('2 glasses'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('add_custom'),
                    onPressed: _custom,
                    child: const Text('Custom'),
                  ),
                ),
              ],
            ),
            if (loggingEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final e in loggingEntries)
                _EntryTile(entry: e, onDelete: () => _svc.remove(e.id)),
            ],
            const SizedBox(height: 18),
            HydrationGoalCard(goal: goal, onAdjust: _adjustGoal),
            if (_svc.manualGoalMl != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('goal_reset'),
                  onPressed: () => _svc.setManualGoal(null),
                  child: const Text('Use the suggested goal'),
                ),
              ),
            const SizedBox(height: 18),
            _heading(context, 'This week'),
            HydrationWeekChart(week: week, onDayTap: _openDay),
            const SizedBox(height: 18),
            _heading(
              context,
              'Hydration history',
              action: history.length >= 7 || _showAllHistory
                  ? TextButton(
                      key: const Key('history_toggle'),
                      onPressed: () =>
                          setState(() => _showAllHistory = !_showAllHistory),
                      child: Text(_showAllHistory ? 'Show less' : 'See all'),
                    )
                  : null,
            ),
            HydrationHistoryList(days: history, onTap: _openDay, now: now),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onDelete, this.onEdit});

  final HydrationEntry entry;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('entry_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appOutlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop_rounded,
            color: Color(0xFF34D399),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${entry.amountMl} ml',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ),
          Text(
            DateFormat('HH:mm').format(entry.loggedAt),
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          if (onEdit != null)
            IconButton(
              key: Key('edit_${entry.id}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              key: Key('delete_${entry.id}'),
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// One day's entries, to correct or remove them.
class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.service,
    required this.dayKey,
    required this.ask,
  });

  final HydrationService service;
  final String dayKey;
  final Future<int?> Function({
    required String title,
    required String label,
    required String hint,
    required int min,
    required int max,
    int? initial,
  })
  ask;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.service.day(widget.dayKey);
    final svc = widget.service;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE d MMMM y').format(d.date),
              key: const Key('day_sheet_title'),
              style: AppTheme.headlineMd.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (d.status) {
                HydrationDayStatus.noData => 'Nothing recorded for this day.',
                HydrationDayStatus.confirmedZero =>
                  'You confirmed you drank nothing this day.',
                HydrationDayStatus.recorded =>
                  '${GlassMath.volumeLabel(d.consumedMl)}'
                      '${d.goal == null ? '' : ' of ${GlassMath.volumeLabel(d.goal!.goalMl)}'}',
              },
              key: const Key('day_sheet_summary'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
            if (d.goal == null)
              Text(
                'The goal for this day was not recorded.',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in d.entries)
                    _EntryTile(
                      entry: e,
                      onDelete: () => svc.remove(e.id),
                      onEdit: () async {
                        final ml = await widget.ask(
                          title: 'Correct amount',
                          label: 'Amount (ml)',
                          hint: '${e.amountMl}',
                          min: 1,
                          max: HydrationService.maxEntryMl,
                          initial: e.amountMl,
                        );
                        if (ml != null) await svc.edit(e.id, ml);
                      },
                    ),
                ],
              ),
            ),
            if (d.status == HydrationDayStatus.noData && !d.isToday)
              OutlinedButton(
                key: const Key('confirm_zero'),
                onPressed: () => svc.confirmNoWater(d.dayKey),
                child: const Text('I drank no water this day'),
              ),
            if (d.status == HydrationDayStatus.confirmedZero)
              OutlinedButton(
                key: const Key('undo_zero'),
                onPressed: () => svc.clearConfirmedZero(d.dayKey),
                child: const Text('Remove this confirmation'),
              ),
          ],
        ),
      ),
    );
  }
}
