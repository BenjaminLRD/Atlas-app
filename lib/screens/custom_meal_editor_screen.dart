import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../models/food_item.dart';
import '../models/meal_prep.dart';
import '../models/recipe.dart';
import '../services/nutrition/nutrition_service.dart';
import '../services/recipes/recipe_stores.dart';
import '../widgets/recipes/recipe_card.dart';
import 'checkout_screen.dart' show GlassPanel;
import 'meal_prep_editor_screen.dart' show FoodPickerSheet;

/// Build or edit your own meal on one screen: name, photo, servings, foods
/// with portions (search the food list or add a missing food by hand), an
/// optional method, and the calculated nutrition per serving.
class CustomMealEditorScreen extends StatefulWidget {
  const CustomMealEditorScreen({
    super.key,
    this.existing,
    this.store,
    this.nutrition,
    this.pickPhoto,
    this.photoBaseDir,
  });

  final Recipe? existing;
  final CustomMealStore? store;
  final NutritionService? nutrition;

  /// Replaces the gallery picker (for tests). Returns a file path or null.
  final Future<String?> Function()? pickPhoto;

  /// Where photos are copied (the app's private folder by default). For tests.
  final Directory? photoBaseDir;

  @override
  State<CustomMealEditorScreen> createState() => _CustomMealEditorScreenState();
}

class _CustomMealEditorScreenState extends State<CustomMealEditorScreen> {
  late final CustomMealStore _store = widget.store ?? CustomMealStore();
  late final NutritionService _nutrition =
      widget.nutrition ?? AppDependencies.instance.nutritionService;

  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _steps = TextEditingController(
    text: widget.existing?.steps.join('\n') ?? '',
  );
  late int _servings = widget.existing?.servings ?? 1;
  late int _prep = widget.existing?.prepMinutes ?? 15;
  late final Set<RecipeCategory> _cats = {...?widget.existing?.categories};
  late final List<RecipeIngredient> _ingredients = [
    ...?widget.existing?.ingredients,
  ];
  String? _imageFile;
  late final String _initial;
  bool _saving = false;
  bool _triedSave = false;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.existing?.imageFile;
    _initial = _snapshot();
  }

  @override
  void dispose() {
    _name.dispose();
    _steps.dispose();
    super.dispose();
  }

  List<String> get _stepList => [
    for (final l in _steps.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  Recipe _draft() =>
      (widget.existing ?? _store.blank(_name.text.trim())).copyWith(
        name: _name.text.trim(),
        categories: _cats,
        prepMinutes: _prep,
        servings: _servings,
        ingredients: List.of(_ingredients),
        steps: _stepList,
        imageFile: _imageFile,
        clearImage: _imageFile == null,
      );

  String _snapshot() => Recipe.encodeAll([
    Recipe(
      id: 'x',
      name: _name.text.trim(),
      origin: RecipeOrigin.custom,
      categories: _cats,
      prepMinutes: _prep,
      servings: _servings,
      ingredients: List.of(_ingredients),
      steps: _stepList,
      imageFile: _imageFile,
      createdAt: DateTime(2000),
      updatedAt: DateTime(2000),
    ),
  ]);

  bool get _dirty => _snapshot() != _initial;

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Give your meal a name.';
    if (n.length > Recipe.maxNameLength) {
      return 'Keep the name under ${Recipe.maxNameLength} characters.';
    }
    return null;
  }

  Future<void> _addIngredients() async {
    final picked = await showModalBottomSheet<List<FoodItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FoodPickerSheet(
        nutrition: _nutrition,
        mealTitle: 'this meal',
        room: Recipe.maxIngredients - _ingredients.length,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final f in picked) {
        final p = PortionUnit.forFood(f);
        if (!p.supported) continue;
        _ingredients.add(
          RecipeIngredient(food: f, quantity: p.defaultQuantity, unit: p.unit),
        );
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final path = widget.pickPhoto != null
          ? await widget.pickPhoto!()
          : (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 85,
            ))?.path;
      if (path == null) return;
      final saved = await MealPhotoStore.persist(
        path,
        baseDir: widget.photoBaseDir,
      );
      if (mounted) setState(() => _imageFile = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that photo.')),
        );
      }
    }
  }

  Future<Recipe?> _save() async {
    setState(() => _triedSave = true);
    if (_nameError != null || _ingredients.isEmpty || _saving) return null;
    setState(() => _saving = true);
    try {
      return await _store.save(_draft());
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the meal. Your changes are still here.',
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
        content: const Text('Your changes to this meal have not been saved.'),
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
          title: Text(widget.existing == null ? 'Create meal' : 'Edit meal'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _photo(context, draft),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('meal_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: Recipe.maxNameLength,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Meal name',
                      hintText: 'e.g. Paneer rice bowl',
                      counterText: '',
                      errorText: _triedSave ? _nameError : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in RecipeCategory.values)
                        FilterChip(
                          key: Key('cat_${c.name}'),
                          label: Text(c.label),
                          selected: _cats.contains(c),
                          onSelected: (on) => setState(() {
                            on ? _cats.add(c) : _cats.remove(c);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _numberRow(
                    context,
                    'Servings it makes',
                    '$_servings',
                    'servings',
                    onMinus: _servings > 1
                        ? () => setState(() => _servings--)
                        : null,
                    onPlus: _servings < Recipe.maxServings
                        ? () => setState(() => _servings++)
                        : null,
                  ),
                  _numberRow(
                    context,
                    'Preparation time',
                    '$_prep min',
                    'prep',
                    onMinus: _prep > 0
                        ? () =>
                              setState(() => _prep = (_prep - 5).clamp(0, 1440))
                        : null,
                    onPlus: _prep < 1440
                        ? () =>
                              setState(() => _prep = (_prep + 5).clamp(0, 1440))
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'INGREDIENTS',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                      if (_ingredients.isNotEmpty)
                        TextButton.icon(
                          key: const Key('add_ingredient'),
                          onPressed: _addIngredients,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  if (_ingredients.isEmpty) _emptyIngredients(context),
                  for (var i = 0; i < _ingredients.length; i++)
                    _IngredientRow(
                      key: ValueKey('${_ingredients[i].food.id}_$i'),
                      index: i,
                      ingredient: _ingredients[i],
                      onChanged: (q) => setState(
                        () => _ingredients[i] = RecipeIngredient(
                          food: _ingredients[i].food,
                          quantity: q,
                          unit: _ingredients[i].unit,
                        ),
                      ),
                      onRemove: () => setState(() => _ingredients.removeAt(i)),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('meal_steps'),
                    controller: _steps,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Method (optional)',
                      hintText: 'One step per line',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _nutritionCard(context, draft),
                ],
              ),
            ),
            _saveBar(context),
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, Recipe draft) {
    return GestureDetector(
      key: const Key('meal_photo'),
      onTap: _pickPhoto,
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RecipeImage(recipe: draft, radius: 20),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _imageFile == null ? 'Add photo' : 'Change photo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberRow(
    BuildContext context,
    String label,
    String value,
    String key, {
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: Key('${key}_minus'),
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        SizedBox(
          width: 64,
          child: Text(
            value,
            key: Key('${key}_value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: Key('${key}_plus'),
          onPressed: onPlus,
          icon: Icon(Icons.add_circle_rounded, color: context.appPrimary),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }

  Widget _emptyIngredients(BuildContext context) {
    final error = _triedSave && _ingredients.isEmpty;
    return GlassPanel(
      key: const Key('ingredients_empty'),
      borderColor: error ? const Color(0xFFF87171) : null,
      child: Column(
        children: [
          Text(
            error
                ? 'Add at least one ingredient to save.'
                : 'No ingredients yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick foods from Atlas, or add a food that is missing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('add_ingredient_empty'),
            onPressed: _addIngredients,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add ingredients'),
            style: FilledButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionCard(BuildContext context, Recipe draft) {
    final n = draft.perServing;
    final t = draft.totals;
    String f(double? v) => recipeNumber(v, partial: n.partial);
    return GlassPanel(
      key: const Key('meal_nutrition'),
      borderColor: context.appPrimary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PER SERVING',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ingredients.isEmpty
                ? 'Add ingredients to see the nutrition'
                : '${f(n.calories)} kcal · P ${f(n.protein)} g · C ${f(n.carbs)} g · F ${f(n.fat)} g',
            key: const Key('meal_per_serving'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          if (_ingredients.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Whole meal (${_servings == 1 ? '1 serving' : '$_servings servings'}): '
              '${recipeNumber(t.calories.total, partial: t.calories.partial)} kcal',
              style: TextStyle(fontSize: 12.5, color: context.appTextSecondary),
            ),
            if (n.partial)
              Text(
                '+ means some foods have no value for that nutrient and are not counted.',
                style: TextStyle(fontSize: 11, color: context.appTextMuted),
              ),
            Text(
              n.estimates
                  ? 'Includes typical or entered values, not lab measurements.'
                  : 'Calculated from the foods you chose.',
              style: TextStyle(fontSize: 11, color: context.appTextMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
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
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('save_meal'),
          onPressed: _saving ? null : _saveAndClose,
          style: FilledButton.styleFrom(
            backgroundColor: context.appPrimary,
            foregroundColor: Colors.black,
            minimumSize: const Size(0, 48),
          ),
          child: const Text(
            'Save meal',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.index,
    required this.ingredient,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final RecipeIngredient ingredient;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = ingredient.portion;
    final q = ingredient.quantity;
    final text = q == q.roundToDouble()
        ? q.round().toString()
        : q.toStringAsFixed(1);
    final item = ingredient.toItem();
    String v(String k) {
      final x = item.valueOf(k);
      return x == null ? '--' : '${x.round()}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient.food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('remove_ingredient_$index'),
                  tooltip: 'Remove ingredient',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: Key('ing_minus_$index'),
                  onPressed: q > p.step ? () => onChanged(q - p.step) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Flexible(
                  child: Text(
                    '$text ${p.label}',
                    key: Key('ing_qty_$index'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('ing_plus_$index'),
                  onPressed: q < 5000 ? () => onChanged(q + p.step) : null,
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: context.appPrimary,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            Text(
              '${v(FoodItem.calorieKey)} kcal · P ${v(FoodItem.proteinKey)} g · '
              'C ${v(FoodItem.carbohydrateKey)} g · F ${v(FoodItem.fatKey)} g · ${item.sourceLabel}',
              style: TextStyle(fontSize: 11.5, color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
