import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/consumed_food.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import '../../models/nutrition_totals.dart';
import '../../providers/fitness_provider.dart';
import '../../services/nutrition/nutrition_calculator.dart';
import 'food_search_sheet.dart';

/// Interactive Meal Card displaying meal details, consumed foods, portion editor, and completion toggle
class MealCard extends StatefulWidget {
  final MealEntry meal;

  const MealCard({super.key, required this.meal});

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool _isExpanded = false;

  void _showEditPortionDialog(BuildContext context, ConsumedFood item) {
    final controller = TextEditingController(
      text: item.quantity.toStringAsFixed(0),
    );
    String selectedUnit = item.unit;
    final units = [
      for (final u in const ['grams', 'servings', 'ml'])
        if (NutritionCalculator.isUnitCompatible(item.food, u)) u,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Edit Portion: ${item.food.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                // Only units that fit the food: no ml for a per-100 g food.
                value: units.contains(selectedUnit) ? selectedUnit : null,
                isExpanded: true,
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    selectedUnit = val;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FitnessProvider.instance.removeFoodFromMeal(
                  widget.meal.id,
                  item.food.id,
                );
                Navigator.of(ctx).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove Food'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(controller.text) ?? item.quantity;
                FitnessProvider.instance.updateFoodQuantity(
                  widget.meal.id,
                  item.food.id,
                  qty,
                  selectedUnit,
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final meal = widget.meal;

    // Each total is exact, a minimum ("14+"), or a dash, see NutritionTotals.
    final totals = NutritionTotals.fromMeals([meal]);

    final isCompleted = meal.completed || meal.isCompleted;
    final foods = meal.consumedFoods;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: AppRadii.borderXl,
        border: Border.all(
          color: isCompleted
              ? (isDark ? AppColors.primaryContainer : AppColors.primary)
              : context.appCardBorder,
          width: isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [context.appCardShadow],
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: AppRadii.borderXl,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Completion Checkbox
                  Checkbox(
                    value: isCompleted,
                    activeColor: isDark
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    checkColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      FitnessProvider.instance.completeMeal(
                        meal.id,
                        val ?? false,
                      );
                    },
                  ),
                  const SizedBox(width: 4),

                  // Meal Name & Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isCompleted
                                ? (isDark
                                      ? AppColors.primaryContainer
                                      : AppColors.primary)
                                : context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // "+" when an item has unknown calories: a minimum.
                          '${totals.caloriesLabel} kcal • ${totals.proteinText} P • ${totals.carbsText} C • ${totals.fatText} F',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add Food Quick Button & Expand Chevron
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primaryContainer,
                    ),
                    onPressed: () {
                      FoodSearchSheet.show(
                        context,
                        mealId: meal.id,
                        mealTitle: meal.name,
                      );
                    },
                    tooltip: 'Add Food',
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.appTextSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded State Content
          if (_isExpanded) ...[
            const Divider(height: 1),

            // Quick Add Shortcut Row for Frequent Foods
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUICK ADD FREQUENT FOODS',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickAddChip(
                          context,
                          'Eggs',
                          'protein_006',
                          100,
                          'piece',
                        ),
                        const SizedBox(width: 6),
                        _buildQuickAddChip(
                          context,
                          'Oats',
                          'carb_001',
                          100,
                          'grams',
                        ),
                        const SizedBox(width: 6),
                        _buildQuickAddChip(
                          context,
                          'Banana',
                          'fruit_002',
                          1,
                          'piece',
                        ),
                        const SizedBox(width: 6),
                        _buildQuickAddChip(
                          context,
                          'Chicken',
                          'protein_001',
                          100,
                          'grams',
                        ),
                        const SizedBox(width: 6),
                        _buildQuickAddChip(
                          context,
                          'Whey Shake',
                          'protein_016',
                          1,
                          'serving',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),

            if (foods.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'No foods added yet',
                      style: AppTheme.bodySm.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        FoodSearchSheet.show(
                          context,
                          mealId: meal.id,
                          mealTitle: meal.name,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('+ Add Food'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: foods.length,
                      separatorBuilder: (_, _) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final item = foods[index];
                        final food = item.food;
                        // The same scaled values the meal totals use.
                        final proteinText =
                            food.isNutrientKnown(FoodItem.proteinKey)
                            ? '${item.protein.toStringAsFixed(0)}g protein'
                            : '\u2014 protein';
                        final caloriesText = item.caloriesKnown
                            ? '${item.calories.toStringAsFixed(0)} kcal'
                            : '\u2014 kcal';

                        return Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food.name,
                                    style: AppTheme.bodySm.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: context.appTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity.toStringAsFixed(0)} ${item.unit} • $proteinText • $caloriesText${_sourceNote(food)}',
                                    style: AppTheme.bodySm.copyWith(
                                      fontSize: 11,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              onPressed: () =>
                                  _showEditPortionDialog(context, item),
                              tooltip: 'Edit Portion',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          FoodSearchSheet.show(
                            context,
                            mealId: meal.id,
                            mealTitle: meal.name,
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('ADD FOOD'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryContainer,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(
    BuildContext context,
    String label,
    String foodId,
    double quantity,
    String unit,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
      label: Text(
        '+ $label',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      backgroundColor: AppColors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final food = FitnessProvider.instance.availableFoods.firstWhere(
          (f) => f.id == foodId,
          orElse: () => FitnessProvider.instance.availableFoods.first,
        );
        await FitnessProvider.instance.addFoodToMeal(
          widget.meal.id,
          food,
          quantity,
          unit,
        );
      },
    );
  }
}

/// A short note on where a logged food's numbers come from, for the ones that
/// are not backed by a recorded source: an AI estimate, or older entries that
/// never recorded one. Foods from a product record, the built-in list or the
/// user's own entry need none.
String _sourceNote(FoodItem food) => switch (food.nutritionSource) {
  NutritionSource.aiEstimate => ' • estimate',
  NutritionSource.unknown => ' • source not recorded',
  _ => '',
};
