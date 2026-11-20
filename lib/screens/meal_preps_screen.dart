import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../models/meal_prep.dart';
import '../services/meal_prep_store.dart';
import '../services/nutrition/nutrition_service.dart';
import 'checkout_screen.dart' show GlassPanel;
import 'meal_prep_editor_screen.dart';

/// The athlete's meal preps: build one, see its totals, add a day to today's
/// food diary, edit, duplicate or delete (delete is immediate with Undo).
class MealPrepsScreen extends StatefulWidget {
  const MealPrepsScreen({super.key, this.store, this.nutrition});

  final MealPrepStore? store;
  final NutritionService? nutrition;

  @override
  State<MealPrepsScreen> createState() => _MealPrepsScreenState();
}

class _MealPrepsScreenState extends State<MealPrepsScreen> {
  late final MealPrepStore _store = widget.store ?? MealPrepStore();
  late List<MealPrep> _preps = _store.all();

  NutritionService get _nutrition =>
      widget.nutrition ?? AppDependencies.instance.nutritionService;

  bool get _showcase => LocalStorage.isShowcaseModeEnabled();

  void _reload() => setState(() => _preps = _store.all());

  Future<void> _openEditor([MealPrep? existing]) async {
    await Navigator.of(context).push<MealPrep>(
      MaterialPageRoute(
        builder: (_) => MealPrepEditorScreen(
          existing: existing,
          store: _store,
          nutrition: widget.nutrition,
        ),
      ),
    );
    if (mounted) _reload();
  }

  void _say(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _logDay(MealPrep prep) async {
    if (_showcase) {
      _say(
        'Logging is switched off in Showcase Mode, so demo plans never '
        'touch a real food diary.',
      );
      return;
    }
    var day = 0;
    if (prep.days > 1) {
      final picked = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Log which day to today?',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              for (var d = 0; d < prep.days; d++)
                ListTile(
                  key: Key('log_day_$d'),
                  title: Text('Day ${d + 1}'),
                  subtitle: Text(
                    prep.itemsFor(d).isEmpty
                        ? 'No foods'
                        : '${_store.pendingToday(prep, d)} of '
                              '${prep.itemsFor(d).length} still to log today',
                  ),
                  enabled: prep.itemsFor(d).isNotEmpty,
                  onTap: () => Navigator.pop(ctx, d),
                ),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      day = picked;
    }
    if (_store.pendingToday(prep, day) == 0) {
      _say('Everything on this day is already in today\'s diary.');
      return;
    }
    try {
      final added = await _store.logDayToToday(prep, day, _nutrition);
      if (!mounted) return;
      _reload();
      _say(
        added == 0
            ? 'Nothing could be logged: those foods have no usable portion.'
            : 'Added $added food${added == 1 ? '' : 's'} to today\'s diary.',
      );
    } catch (_) {
      if (mounted) _say('Could not add to the diary. Nothing was changed.');
    }
  }

  Future<void> _duplicate(MealPrep p) async {
    await _store.duplicate(p.id);
    if (!mounted) return;
    _reload();
    _say('Copied "${p.name}".');
  }

  Future<void> _delete(MealPrep p) async {
    await _store.delete(p.id);
    if (!mounted) return;
    _reload();
    _say(
      'Deleted "${p.name}".',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _store.save(p);
          if (mounted) _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: const Text('Meal preps'),
      ),
      floatingActionButton: _preps.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('new_prep'),
              onPressed: () => _openEditor(),
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New meal prep',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: _preps.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: _preps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _card(context, _preps[i]),
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lunch_dining_rounded,
              size: 48,
              color: context.appPrimary,
            ),
            const SizedBox(height: 14),
            Text(
              'Plan your meal prep',
              key: const Key('preps_empty'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose foods for breakfast, lunch, dinner and snacks, set the '
              'portions and see the totals. Add a day to your food diary in one tap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary, height: 1.35),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('new_prep_empty'),
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a meal prep'),
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, MealPrep p) {
    final t = p.totals;
    String perDay() {
      if (t.isEmpty) return 'No foods yet';
      if (!t.calories.known) return 'Calories not recorded';
      final avg = (t.calories.total! / p.days).round();
      return '${t.calories.partial ? '~' : ''}$avg kcal a day'
          '${t.calories.partial ? ' (some foods have no calories recorded)' : ''}';
    }

    return GlassPanel(
      key: Key('prep_${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: Key('prep_menu_${p.id}'),
                tooltip: 'More',
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _openEditor(p);
                    case 'duplicate':
                      _duplicate(p);
                    case 'delete':
                      _delete(p);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Text(
            '${p.days} day${p.days == 1 ? '' : 's'} · '
            '${t.itemCount} food${t.itemCount == 1 ? '' : 's'} · ${perDay()}',
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
          if (t.hasEstimates && !t.isEmpty)
            Text(
              'Includes typical or estimated values.',
              style: TextStyle(fontSize: 11, color: context.appTextMuted),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('log_${p.id}'),
              onPressed: t.isEmpty ? null : () => _logDay(p),
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: const Text('Add to today\'s diary'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appPrimary,
                side: BorderSide(color: context.appPrimary),
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
