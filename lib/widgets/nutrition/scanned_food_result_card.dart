import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/food_item.dart';
import '../../providers/fitness_provider.dart';
import '../../services/nutrition/nutrition_calculator.dart';
import 'custom_food_modal.dart';
import 'food_result_parts.dart';

/// Modal bottom sheet or card widget displaying scanned food product details and actions.
class ScannedFoodResultCard extends StatefulWidget {
  final FoodItem food;
  final String currentMealId;
  final String currentMealTitle;

  const ScannedFoodResultCard({
    super.key,
    required this.food,
    this.currentMealId = 'Breakfast',
    this.currentMealTitle = 'Breakfast',
  });

  static Future<void> show(
    BuildContext context, {
    required FoodItem food,
    String currentMealId = 'Breakfast',
    String currentMealTitle = 'Breakfast',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScannedFoodResultCard(
        food: food,
        currentMealId: currentMealId,
        currentMealTitle: currentMealTitle,
      ),
    );
  }

  @override
  State<ScannedFoodResultCard> createState() => _ScannedFoodResultCardState();
}

class _ScannedFoodResultCardState extends State<ScannedFoodResultCard> {
  late String _selectedMealTitle;
  late String _selectedMealId;
  late double _quantity;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _selectedMealTitle = widget.currentMealTitle.isNotEmpty
        ? widget.currentMealTitle
        : 'Breakfast';
    _selectedMealId = widget.currentMealId.isNotEmpty
        ? widget.currentMealId
        : 'Breakfast';
    _quantity = 100.0;
    final label = widget.food.servingUnit.isNotEmpty
        ? widget.food.servingUnit
        : 'g';
    // The unit label must fit the basis: a per-100 ml product is shown and
    // logged in ml, never as grams.
    _unit = NutritionCalculator.isUnitCompatible(widget.food, label)
        ? label
        : (widget.food.nutritionBasis == NutritionBasis.per100ml ? 'ml' : 'g');
    // Values for one serving or one package are logged as one of those.
    if (widget.food.nutritionBasis == NutritionBasis.perServing) {
      _quantity = 1.0;
      _unit = 'serving';
    } else if (widget.food.nutritionBasis == NutritionBasis.perPackage) {
      _quantity = 1.0;
      _unit = 'package';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final scaled = NutritionCalculator.calculateNutrition(
      widget.food,
      _quantity,
      _unit,
    );
    final food = widget.food;
    // No nutrition at all: show that, not zeros. Without calories the food
    // cannot be logged honestly, so logging is replaced by manual entry.
    final unavailable = food.nutritionUnavailable;
    final cannotLog = food.caloriesUnknown;
    double? known(String nutrient, double value) =>
        food.isNutrientKnown(nutrient) ? value : null;

    return Container(
      decoration: const BoxDecoration(
        color: FoodResultStyle.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Product: image, name, brand, serving, and where the data is from.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: FoodResultStyle.raised,
                      child: widget.food.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.food.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackImage(),
                            )
                          : _buildFallbackImage(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.food.name,
                          style: FoodResultStyle.title(size: 18),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.food.brand != null &&
                            widget.food.brand!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.food.brand!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FoodResultStyle.body(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          'Serving: ${widget.food.servingSize}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FoodResultStyle.body(size: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: FoodResultStyle.muted,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SourceBadge(
                  kind: unavailable
                      ? FoodSourceKind.unavailable
                      : (food.isCustom
                            ? FoodSourceKind.userEntry
                            : FoodSourceKind.database),
                ),
              ),
              const SizedBox(height: 12),

              // Nutrition: calories first, then macros.
              if (unavailable)
                _buildUnavailableNotice(context)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FoodResultStyle.raised,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: CalorieHero(
                              value: food.isNutrientKnown(FoodItem.calorieKey)
                                  ? scaled.calories.toStringAsFixed(0)
                                  : '—',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _referenceLabel(food),
                            maxLines: 1,
                            style: FoodResultStyle.body(size: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      MacroStrip(
                        entries: [
                          MacroEntry(
                            'Protein',
                            known(FoodItem.proteinKey, scaled.protein),
                            FoodResultStyle.protein,
                            energyPerGram: 4,
                          ),
                          MacroEntry(
                            'Carbs',
                            known(
                              FoodItem.carbohydrateKey,
                              scaled.carbohydrates,
                            ),
                            FoodResultStyle.carbs,
                            energyPerGram: 4,
                          ),
                          MacroEntry(
                            'Fat',
                            known(FoodItem.fatKey, scaled.fats),
                            FoodResultStyle.fat,
                            energyPerGram: 9,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (!unavailable) ...[
                const SizedBox(height: 10),
                MoreNutrients(food: food, scaled: scaled),
              ],
              if (food.nutritionSource == NutritionSource.openFoodFacts &&
                  food.sourceUrl != null) ...[
                const SizedBox(height: 10),
                SourceNote(
                  food: food,
                  textKey: const Key('scanned_source_note'),
                ),
              ],
              if (food.hasUnknownNutrition && !unavailable) ...[
                const SizedBox(height: 10),
                const NoticeBox(
                  children: [
                    NoticeLine(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Some values are missing for this product (shown as —). '
                          'They are logged as unknown, not as 0, and left out '
                          'of your totals, which then show as a minimum.',
                      textKey: Key('scanned_partial_nutrition_note'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              if (cannotLog) ...[
                FilledButton.icon(
                  key: const Key('scanned_enter_nutrition'),
                  onPressed: _enterNutritionManually,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Enter nutrition manually'),
                  style: ResultButtons.primary(),
                ),
                const SizedBox(height: 8),
                // Allowed, but only after an explicit confirmation.
                TextButton.icon(
                  key: const Key('scanned_log_without_calories'),
                  onPressed: () async {
                    final ok = await confirmLogUnknownCalories(
                      context,
                      widget.food.name,
                    );
                    if (!ok || !mounted) return;
                    await _addFoodToMeal(
                      provider,
                      _selectedMealId,
                      _selectedMealTitle,
                      confirmedUnknownCalories: true,
                    );
                  },
                  icon: const Icon(Icons.playlist_add_rounded, size: 16),
                  label: const Text('Log without calories'),
                  style: TextButton.styleFrom(
                    foregroundColor: FoodResultStyle.muted,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ] else ...[
                // One clear primary action, then the quiet ones.
                FilledButton(
                  onPressed: () => _addFoodToMeal(
                    provider,
                    _selectedMealId,
                    _selectedMealTitle,
                  ),
                  style: ResultButtons.primary(),
                  child: Text(
                    'ADD TO ${_selectedMealTitle.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await provider.saveScannedFood(widget.food);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Product saved to offline library!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text('Save Product'),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: FoodResultStyle.text,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _enterNutritionManually,
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text('Edit Product Details'),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: FoodResultStyle.text,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Quick add straight to another meal.
                Text(
                  'LOG TO MEAL',
                  style: FoodResultStyle.body(
                    size: 10,
                    weight: FontWeight.w800,
                  ).copyWith(letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final meal in const [
                      'Breakfast',
                      'Lunch',
                      'Dinner',
                      'Snacks',
                    ]) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _addFoodToMeal(provider, meal, meal),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FoodResultStyle.text,
                            side: const BorderSide(
                              color: FoodResultStyle.hairline,
                            ),
                            backgroundColor: FoodResultStyle.raised,
                            minimumSize: const Size(0, 40),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              meal,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (meal != 'Snacks') const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFoodToMeal(
    FitnessProvider provider,
    String mealId,
    String mealTitle, {
    bool confirmedUnknownCalories = false,
  }) async {
    // Never log a food whose calories are unknown as if it were 0 kcal,
    // unless the user has explicitly confirmed it.
    if (widget.food.caloriesUnknown && !confirmedUnknownCalories) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await provider.saveScannedFood(widget.food);
    await provider.addFoodToMeal(mealId, widget.food, _quantity, _unit);
    if (mounted) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added ${widget.food.name} to $mealTitle'),
          backgroundColor: AppColors.primaryContainer,
        ),
      );
    }
  }

  /// Opens the existing product editor so the user can type in the values from
  /// the package.
  void _enterNutritionManually() {
    Navigator.of(context).pop();
    CustomFoodModal.show(context, initialFood: widget.food);
  }

  /// What the numbers shown are for: "per 100 ml", "per serving (30 g)"...
  String _referenceLabel(FoodItem food) {
    String size(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    switch (food.nutritionBasis) {
      case NutritionBasis.perServing:
        final q = food.servingQuantity;
        return q == null
            ? 'per serving'
            : 'per serving (${size(q)} ${food.servingQuantityUnit})';
      case NutritionBasis.perPackage:
        final q = food.packageQuantity;
        return q == null
            ? 'per package'
            : 'per package (${size(q)} ${food.packageQuantityUnit})';
      default:
        return 'per ${_quantity.toStringAsFixed(0)} $_unit';
    }
  }

  /// Shown instead of the numbers when the product has no nutrition data.
  Widget _buildUnavailableNotice(BuildContext context) {
    return Container(
      key: const Key('scanned_nutrition_unavailable'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FoodResultStyle.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FoodResultStyle.caution.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: FoodResultStyle.caution,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nutrition data unavailable',
                  style: FoodResultStyle.body(
                    size: 14,
                    color: FoodResultStyle.text,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The product was found, but the database has no calories or '
            'macros for it. They are not 0: they are unknown. You can enter '
            'them from the package.',
            style: FoodResultStyle.body(size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.fastfood_rounded, size: 28, color: Colors.grey),
        ],
      ),
    );
  }
}
