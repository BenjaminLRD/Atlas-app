import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../models/recipe.dart';
import '../services/nutrition/nutrition_service.dart';
import '../services/recipes/recipe_stores.dart';
import '../widgets/recipes/recipe_card.dart';
import 'custom_meal_editor_screen.dart';
import 'meal_preps_screen.dart';
import 'recipe_detail_screen.dart';

enum _Filter { all, breakfast, lunch, dinner, snack, highProtein, saved }

enum RecipeSort {
  topRated('Top rated'),
  protein('Most protein'),
  calories('Fewest calories'),
  quickest('Quickest');

  final String label;
  const RecipeSort(this.label);
}

/// Meal prep home: discover Atlas recipes and community recipes, search,
/// filter and sort them, build your own meals, and open your meal plans.
class MealPrepHubScreen extends StatefulWidget {
  const MealPrepHubScreen({super.key, this.nutrition, this.hub});

  final NutritionService? nutrition;
  final RecipeHub? hub;

  @override
  State<MealPrepHubScreen> createState() => _MealPrepHubScreenState();
}

class _MealPrepHubScreenState extends State<MealPrepHubScreen> {
  late final NutritionService _nutrition =
      widget.nutrition ?? AppDependencies.instance.nutritionService;
  late final RecipeHub _hub =
      widget.hub ?? RecipeHub(foods: _nutrition.getAvailableFoods());
  final _saved = SavedRecipesStore();
  final _mealStore = CustomMealStore();
  final _search = TextEditingController();

  _Filter _filter = _Filter.all;
  RecipeSort _sort = RecipeSort.topRated;

  late List<Recipe> _mine = _hub.mine();
  late final List<Recipe> _atlas = _hub.atlas();
  late final List<Recipe> _community = _hub.community();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _search.text.trim().isNotEmpty || _filter != _Filter.all;

  bool _matches(Recipe r) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        r.name,
        r.description,
        r.creatorName ?? '',
        for (final i in r.ingredients) i.food.name,
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.breakfast:
        return r.categories.contains(RecipeCategory.breakfast);
      case _Filter.lunch:
        return r.categories.contains(RecipeCategory.lunch);
      case _Filter.dinner:
        return r.categories.contains(RecipeCategory.dinner);
      case _Filter.snack:
        return r.categories.contains(RecipeCategory.snack);
      case _Filter.highProtein:
        return r.isHighProtein;
      case _Filter.saved:
        return _saved.isSaved(r.id);
    }
  }

  List<Recipe> _sorted(List<Recipe> list) {
    final ratings = _hub.ratings;
    final out = [...list];
    int cmpNullLast(double? a, double? b, {bool desc = true}) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return desc ? b.compareTo(a) : a.compareTo(b);
    }

    out.sort((a, b) {
      final c = switch (_sort) {
        RecipeSort.topRated => cmpNullLast(
          ratings.summaryFor(a.id).average,
          ratings.summaryFor(b.id).average,
        ),
        RecipeSort.protein => cmpNullLast(
          a.perServing.protein,
          b.perServing.protein,
        ),
        RecipeSort.calories => cmpNullLast(
          a.perServing.calories,
          b.perServing.calories,
          desc: false,
        ),
        RecipeSort.quickest => a.prepMinutes.compareTo(b.prepMinutes),
      };
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  Future<void> _open(Recipe r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: r,
          hub: _hub,
          nutrition: _nutrition,
          saved: _saved,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _create([Recipe? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomMealEditorScreen(
          existing: existing,
          store: _mealStore,
          nutrition: _nutrition,
        ),
      ),
    );
    if (mounted) setState(() => _mine = _hub.mine());
  }

  void _say(String m, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), action: action));
  }

  Future<void> _duplicate(Recipe r) async {
    await _mealStore.duplicate(r.id);
    if (!mounted) return;
    setState(() => _mine = _hub.mine());
    _say('Copied "${r.name}".');
  }

  Future<void> _delete(Recipe r) async {
    await _mealStore.delete(r.id);
    if (!mounted) return;
    setState(() => _mine = _hub.mine());
    _say(
      'Deleted "${r.name}".',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _mealStore.save(r);
          if (mounted) setState(() => _mine = _hub.mine());
        },
      ),
    );
  }

  Future<void> _toggleSaved(Recipe r) async {
    await _saved.toggle(r.id);
    if (mounted) setState(() {});
  }

  Widget _card(Recipe r) {
    final summary = _hub.ratings.summaryFor(r.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          RecipeCard(
            key: Key('card_${r.id}'),
            recipe: r,
            rating: summary,
            saved: _saved.isSaved(r.id),
            onTap: () => _open(r),
            onToggleSaved: () => _toggleSaved(r),
          ),
          if (r.origin == RecipeOrigin.custom)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(
                    key: Key('edit_${r.id}'),
                    onPressed: () => _create(r),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    key: Key('dup_${r.id}'),
                    onPressed: () => _duplicate(r),
                    child: const Text('Duplicate'),
                  ),
                  TextButton(
                    key: Key('del_${r.id}'),
                    onPressed: () => _delete(r),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(String text, {Widget? trailing, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.appTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _note(String key, IconData icon, String text) {
    return Container(
      key: Key(key),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appOutlineVariant),
        color: Colors.white.withValues(alpha: context.isDarkMode ? 0.04 : 0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.appTextSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _sorted(
      [..._mine, ..._atlas, ..._community].where(_matches).toList(),
    );
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: const Text('Meal prep'),
        actions: [
          IconButton(
            key: const Key('open_plans'),
            tooltip: 'My meal plans',
            icon: const Icon(Icons.event_note_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MealPrepsScreen(nutrition: _nutrition),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_meal'),
        onPressed: () => _create(),
        backgroundColor: context.appPrimary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create meal',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TextField(
            key: const Key('recipe_search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search meals, ingredients or creators',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('filter_${f.name}'),
                        label: Text(switch (f) {
                          _Filter.all => 'All',
                          _Filter.breakfast => 'Breakfast',
                          _Filter.lunch => 'Lunch',
                          _Filter.dinner => 'Dinner',
                          _Filter.snack => 'Snacks',
                          _Filter.highProtein => 'High protein',
                          _Filter.saved => 'Saved',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<RecipeSort>(
              key: const Key('sort_menu'),
              initialValue: _sort,
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => [
                for (final s in RecipeSort.values)
                  PopupMenuItem(value: s, child: Text(s.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: context.appPrimary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Sort: ${_sort.label}',
                        key: const Key('sort_label'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.appPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_filtering) ...[
            _heading('${results.length} meal${results.length == 1 ? '' : 's'}'),
            if (results.isEmpty)
              _note(
                'no_results',
                Icons.search_off_rounded,
                _filter == _Filter.saved
                    ? 'You have not saved any recipes yet. Tap the bookmark on a recipe to keep it here.'
                    : 'No meals match. Try another word or filter.',
              )
            else
              for (final r in results) _card(r),
          ] else ...[
            _heading(
              'My meals',
              subtitle: 'Meals you built',
              trailing: TextButton.icon(
                key: const Key('create_meal_inline'),
                onPressed: () => _create(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create'),
              ),
            ),
            if (_mine.isEmpty)
              _note(
                'my_meals_empty',
                Icons.restaurant_menu_rounded,
                'Build your own meal from foods in Atlas, or add a food that '
                    'is missing. It takes about a minute.',
              )
            else
              for (final r in _sorted(_mine)) _card(r),
            _heading(
              'Atlas recipes',
              subtitle: 'Written by Atlas from its food list',
            ),
            for (final r in _sorted(_atlas)) _card(r),
            _heading(
              'Community recipes',
              subtitle: _hub.communityAvailable
                  ? 'Sample recipes from sample athletes'
                  : 'Shared by Atlas users',
            ),
            if (_hub.communityAvailable)
              for (final r in _sorted(_community)) _card(r)
            else
              _note(
                'community_unavailable',
                Icons.groups_rounded,
                'Recipes shared by other Atlas users are not switched on yet. '
                    'They need a small backend update that is waiting for approval. '
                    'Your own meals and Atlas recipes work now.',
              ),
          ],
        ],
      ),
    );
  }
}
