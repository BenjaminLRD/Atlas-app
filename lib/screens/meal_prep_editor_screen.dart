import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_prep.dart';
import '../services/meal_prep_store.dart';
import '../services/nutrition/nutrition_service.dart';
import '../widgets/nutrition/custom_food_modal.dart';
import 'checkout_screen.dart' show GlassPanel;

/// Build or edit a meal prep: name, number of days, and foods per meal with
/// portions, readable totals per meal, per day and for the whole plan.
///
/// Totals add only the values that are known. A food with an unknown value is
/// listed as "not recorded" and the total says it is incomplete; unknown is
/// never counted as zero.
class MealPrepEditorScreen extends StatefulWidget {
  const MealPrepEditorScreen({
    super.key,
    this.existing,
    this.store,
    this.nutrition,
  });

  final MealPrep? existing;
  final MealPrepStore? store;

  /// Where the food picker searches. Defaults to the app's nutrition service.
  final NutritionService? nutrition;

  @override
  State<MealPrepEditorScreen> createState() => _MealPrepEditorScreenState();
}

class _MealPrepEditorScreenState extends State<MealPrepEditorScreen> {
  late final MealPrepStore _store = widget.store ?? MealPrepStore();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? 'Meal prep',
  );
  late int _days = widget.existing?.days ?? 1;
  late final List<MealPrepItem> _items = [...?widget.existing?.items];
  late final Map<String, String> _loggedOn = {...?widget.existing?.loggedOn};
  late final String _initial;

  @override
  void initState() {
    super.initState();
    // Taken now, before any edit, so unsaved changes can be detected.
    _initial = _snapshot();
  }

  int _day = 0;
  int _idCounter = 0;
  bool _saving = false;
  bool _triedSave = false;

  String _snapshot() => MealPrep.encodeAll([_draft()]);

  MealPrep _draft() => MealPrep(
    id: widget.existing?.id ?? 'draft',
    name: _name.text.trim(),
    days: _days,
    items: List.unmodifiable(_items),
    createdAt: DateTime(2000),
    updatedAt: DateTime(2000),
    loggedOn: _loggedOn,
  );

  bool get _dirty => _snapshot() != _initial;

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Give your meal prep a name.';
    if (n.length > MealPrep.maxNameLength) {
      return 'Keep the name under ${MealPrep.maxNameLength} characters.';
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _newItemId() =>
      'it_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  Future<void> _addFood(MealCategory meal) async {
    final nutrition =
        widget.nutrition ?? AppDependencies.instance.nutritionService;
    final picked = await showModalBottomSheet<List<FoodItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FoodPickerSheet(
        nutrition: nutrition,
        mealTitle: _mealLabel(meal),
        room: MealPrep.maxItems - _items.length,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final f in picked) {
        final unit = PortionUnit.forFood(f);
        _items.add(
          MealPrepItem(
            id: _newItemId(),
            food: f,
            quantity: unit.defaultQuantity,
            unit: unit.unit,
            meal: meal,
            day: _day,
          ),
        );
      }
    });
  }

  void _changeDays(int next) {
    if (next < 1 || next > MealPrep.maxDays) return;
    if (next < _days) {
      final lastUsed = _draft().lastUsedDay;
      if (lastUsed >= next) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Day ${lastUsed + 1} has foods. Remove them first, or keep '
                'the day.',
              ),
            ),
          );
        return;
      }
    }
    setState(() {
      _days = next;
      if (_day >= _days) _day = _days - 1;
    });
  }

  /// Copies this day's foods onto every other day that is still empty.
  void _repeatOnEmptyDays() {
    final source = _items.where((i) => i.day == _day).toList();
    if (source.isEmpty) return;
    setState(() {
      for (var d = 0; d < _days; d++) {
        if (d == _day || _items.any((i) => i.day == d)) continue;
        for (final i in source) {
          _items.add(
            MealPrepItem(
              id: _newItemId(),
              food: i.food,
              quantity: i.quantity,
              unit: i.unit,
              meal: i.meal,
              day: d,
            ),
          );
        }
      }
    });
  }

  Future<MealPrep?> _save() async {
    setState(() => _triedSave = true);
    if (_nameError != null || _items.isEmpty || _saving) return null;
    setState(() => _saving = true);
    try {
      final base = widget.existing ?? _store.blank(_name.text.trim());
      return await _store.save(
        base.copyWith(
          name: _name.text.trim(),
          days: _days,
          items: List.of(_items),
          loggedOn: _loggedOn,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the meal prep. Your changes are still here.',
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveAndClose() async {
    final saved = await _save();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  Future<bool> _confirmDiscard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your changes to this meal prep have not been saved.',
        ),
        actions: [
          TextButton(
            key: const Key('keep_editing'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            key: const Key('discard_changes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  static String _mealLabel(MealCategory m) => switch (m) {
    MealCategory.breakfast => 'Breakfast',
    MealCategory.lunch => 'Lunch',
    MealCategory.dinner => 'Dinner',
    MealCategory.snack => 'Snacks',
  };

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appBackground,
          elevation: 0,
          title: Text(
            widget.existing == null ? 'New meal prep' : 'Edit meal prep',
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  TextField(
                    key: const Key('prep_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: MealPrep.maxNameLength,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Meal prep name',
                      hintText: 'e.g. High-protein week',
                      counterText: '',
                      errorText: _triedSave ? _nameError : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _daysRow(context),
                  if (_days > 1) ...[
                    const SizedBox(height: 10),
                    _dayChips(context),
                  ],
                  const SizedBox(height: 12),
                  _totalsCard(
                    context,
                    _days > 1 ? 'Day ${_day + 1} total' : 'Day total',
                    draft.totalsForDay(_day),
                    key: const Key('day_totals'),
                  ),
                  const SizedBox(height: 14),
                  for (final meal in MealCategory.values)
                    _mealSection(context, draft, meal),
                  if (_days > 1 && _items.any((i) => i.day == _day))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('repeat_day'),
                        onPressed: _repeatOnEmptyDays,
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Copy this day to empty days'),
                      ),
                    ),
                  if (_triedSave && _items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Add at least one food to save.',
                        key: const Key('prep_empty_error'),
                        style: const TextStyle(color: Color(0xFFF87171)),
                      ),
                    ),
                ],
              ),
            ),
            _summaryBar(context, draft),
          ],
        ),
      ),
    );
  }

  Widget _daysRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Days covered',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: const Key('days_minus'),
          tooltip: 'Fewer days',
          onPressed: _days > 1 ? () => _changeDays(_days - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$_days',
            key: const Key('days_value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: const Key('days_plus'),
          tooltip: 'More days',
          onPressed: _days < MealPrep.maxDays
              ? () => _changeDays(_days + 1)
              : null,
          icon: Icon(Icons.add_circle_rounded, color: context.appPrimary),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }

  Widget _dayChips(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var d = 0; d < _days; d++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('day_chip_$d'),
                label: Text('Day ${d + 1}'),
                selected: _day == d,
                onSelected: (_) => setState(() => _day = d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mealSection(BuildContext context, MealPrep draft, MealCategory meal) {
    final items = draft.itemsFor(_day, meal);
    final totals = draft.totalsForMeal(_day, meal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        key: Key('meal_${meal.name}'),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mealLabel(meal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: Key('add_food_${meal.name}'),
                  onPressed: _items.length >= MealPrep.maxItems
                      ? null
                      : () => _addFood(meal),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add food'),
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Nothing here yet.',
                  style: TextStyle(fontSize: 13, color: context.appTextMuted),
                ),
              )
            else ...[
              for (final item in items)
                _ItemRow(
                  key: ValueKey(item.id),
                  item: item,
                  onQuantity: (q) => setState(() {
                    final i = _items.indexWhere((e) => e.id == item.id);
                    if (i >= 0) _items[i] = item.copyWith(quantity: q);
                    // A changed portion is a new thing to log.
                    _loggedOn.remove(item.id);
                  }),
                  onRemove: () => setState(
                    () => _items.removeWhere((e) => e.id == item.id),
                  ),
                ),
              const Divider(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text(
                  'Meal total: ${_line(totals)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "420 kcal · P 32 g · C 40 g · F 12 g", with "not recorded" where a
  /// nutrient has no known value, and "+" when only some foods were counted.
  static String _line(NutritionTotals t) {
    String f(NutrientTotal n, String unit, {String prefix = ''}) {
      if (!n.known) return '$prefix not recorded'.trim();
      final v = n.total!;
      final text = unit == 'kcal' ? v.round().toString() : v.toStringAsFixed(0);
      return '$prefix$text$unit${n.partial ? '+' : ''}'.trim();
    }

    return [
      f(t.calories, ' kcal'),
      f(t.protein, ' g', prefix: 'P '),
      f(t.carbs, ' g', prefix: 'C '),
      f(t.fat, ' g', prefix: 'F '),
    ].join(' · ');
  }

  Widget _totalsCard(
    BuildContext context,
    String title,
    NutritionTotals t, {
    Key? key,
  }) {
    return GlassPanel(
      key: key,
      borderColor: context.appPrimary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.isEmpty ? 'Add foods to see the total' : _line(t),
            key: key == null ? null : const Key('totals_text'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          if (t.anyPartial)
            Text(
              '+ means some foods have no value for that nutrient and are not '
              'counted.',
              style: TextStyle(fontSize: 11, color: context.appTextMuted),
            ),
          if (t.hasEstimates)
            Text(
              'Includes typical or estimated values, not lab measurements.',
              style: TextStyle(fontSize: 11, color: context.appTextMuted),
            ),
        ],
      ),
    );
  }

  Widget _summaryBar(BuildContext context, MealPrep draft) {
    final total = draft.totals;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appOutlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            total.isEmpty
                ? 'No foods yet'
                : '${total.itemCount} food${total.itemCount == 1 ? '' : 's'}'
                      ' · $_days day${_days == 1 ? '' : 's'}'
                      ' · ${_line(total)}',
            key: const Key('prep_summary'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save_prep'),
              onPressed: _saving ? null : _saveAndClose,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Save meal prep',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.onQuantity,
    required this.onRemove,
  });

  final MealPrepItem item;
  final ValueChanged<double> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final unit = PortionUnit.forFood(item.food);
    String v(double? x, String suffix) =>
        x == null ? '--' : '${x.round()}$suffix';
    final kcal = item.valueOf(FoodItem.calorieKey);
    final protein = item.valueOf(FoodItem.proteinKey);
    final carbs = item.valueOf(FoodItem.carbohydrateKey);
    final fat = item.valueOf(FoodItem.fatKey);
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.round().toString()
        : item.quantity.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.food.name +
                      (item.food.brand == null ? '' : ' · ${item.food.brand}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              IconButton(
                key: Key('remove_${item.id}'),
                tooltip: 'Remove food',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: context.appTextSecondary,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                key: Key('qty_minus_${item.id}'),
                tooltip: 'Smaller portion',
                onPressed: item.quantity > unit.step
                    ? () => onQuantity(item.quantity - unit.step)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Text(
                '$qty ${unit.label}',
                key: Key('qty_${item.id}'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              IconButton(
                key: Key('qty_plus_${item.id}'),
                tooltip: 'Bigger portion',
                onPressed: item.quantity < 5000
                    ? () => onQuantity(item.quantity + unit.step)
                    : null,
                icon: Icon(Icons.add_circle_rounded, color: context.appPrimary),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          Text(
            unit.supported
                ? '${v(kcal, ' kcal')} · P ${v(protein, ' g')} · '
                      'C ${v(carbs, ' g')} · F ${v(fat, ' g')}'
                : 'Portion cannot be calculated: this food has no per-100 g, '
                      'per-100 ml or per-serving basis.',
            key: Key('nutrition_${item.id}'),
            style: TextStyle(fontSize: 12.5, color: context.appTextSecondary),
          ),
          Text(
            item.sourceLabel,
            style: TextStyle(
              fontSize: 11,
              color: item.isEstimate
                  ? context.appTextMuted
                  : context.appPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search the food list and pick foods to add to a meal.
class FoodPickerSheet extends StatefulWidget {
  const FoodPickerSheet({
    super.key,
    required this.nutrition,
    required this.mealTitle,
    required this.room,
  });

  final NutritionService nutrition;
  final String mealTitle;
  final int room;

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  final _search = TextEditingController();
  final Map<String, FoodItem> _picked = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FoodItem> get _results {
    final q = _search.text.trim();
    if (q.isEmpty) {
      final recent = widget.nutrition.getRecentFoods();
      final all = widget.nutrition.getAvailableFoods();
      final seen = <String>{};
      return [
        for (final f in [...recent, ...all])
          if (seen.add(f.id)) f,
      ].take(40).toList();
    }
    return widget.nutrition.searchFoods(q).take(60).toList();
  }

  String _per(FoodItem f) {
    final basis = switch (f.nutritionBasis) {
      NutritionBasis.per100g => 'per 100 g',
      NutritionBasis.per100ml => 'per 100 ml',
      NutritionBasis.perServing => 'per serving',
      NutritionBasis.perPackage => 'per package',
      NutritionBasis.unknown => 'portion basis unknown',
    };
    final kcal = f.isNutrientKnown(FoodItem.calorieKey)
        ? '${f.calories.round()} kcal'
        : 'kcal not recorded';
    return '$kcal $basis';
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appOutlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('food_search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search foods for ${widget.mealTitle}',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                key: const Key('add_custom_food'),
                onPressed: () async {
                  await CustomFoodModal.show(context);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Can\'t find it? Add custom food'),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No foods match. Try another word, or add the food '
                        'from the Nutrition tab first.',
                        key: const Key('food_no_results'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.appTextSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final f = results[i];
                      final selected = _picked.containsKey(f.id);
                      final full = !selected && _picked.length >= widget.room;
                      final portionOk = PortionUnit.forFood(f).supported;
                      return ListTile(
                        key: Key('pick_food_${f.id}'),
                        enabled: !full && portionOk,
                        title: Text(
                          f.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          portionOk
                              ? _per(f)
                              : '${_per(f)} · cannot be portioned',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: selected
                              ? context.appPrimary
                              : context.appTextSecondary,
                        ),
                        onTap: () => setState(() {
                          if (selected) {
                            _picked.remove(f.id);
                          } else {
                            _picked[f.id] = f;
                          }
                        }),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('food_picker_add'),
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, _picked.values.toList()),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 50),
                ),
                child: Text(
                  _picked.isEmpty
                      ? 'Select foods to add'
                      : 'Add ${_picked.length} food${_picked.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
