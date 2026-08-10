import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/consumed_food.dart';
import '../../models/meal_entry.dart';
import '../../providers/fitness_provider.dart';
import 'food_search_sheet.dart';

/// Interactive Meal Card displaying meal details, consumed foods, portion editor, and completion toggle
class MealCard extends StatefulWidget {
  final MealEntry meal;

  const MealCard({
    super.key,
    required this.meal,
  });

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool _isExpanded = false;

  void _showEditPortionDialog(BuildContext context, ConsumedFood item) {
    final controller = TextEditingController(text: item.quantity.toStringAsFixed(0));
    String selectedUnit = item.unit;

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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedUnit,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'grams', child: Text('grams')),
                  DropdownMenuItem(value: 'servings', child: Text('servings')),
                  DropdownMenuItem(value: 'ml', child: Text('ml')),
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
                FitnessProvider.instance.removeFoodFromMeal(widget.meal.id, item.food.id);
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

    final totalCals = meal.totalCalories;
    final totalP = meal.totalProtein;
    final totalC = meal.totalCarbohydrates;
    final totalF = meal.totalFats;

    final isCompleted = meal.completed || meal.isCompleted;
    final foods = meal.consumedFoods;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppColors.primaryContainer.withValues(alpha: 0.5)
              : context.appOutlineVariant.withValues(alpha: 0.3),
          width: isCompleted ? 1.5 : 1.0,
        ),
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Completion Checkbox
                  Checkbox(
                    value: isCompleted,
                    activeColor: AppColors.primaryContainer,
                    checkColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      FitnessProvider.instance.completeMeal(meal.id, val ?? false);
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
                                ? AppColors.primaryContainer
                                : context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totalCals.toStringAsFixed(0)} kcal • ${totalP.toStringAsFixed(0)}g P • ${totalC.toStringAsFixed(0)}g C • ${totalF.toStringAsFixed(0)}g F',
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
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryContainer),
                    onPressed: () {
                      FoodSearchSheet.show(context, mealId: meal.id, mealTitle: meal.name);
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
                        FoodSearchSheet.show(context, mealId: meal.id, mealTitle: meal.name);
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        final scaledP = (food.protein * (item.quantity / 100.0));
                        final scaledCals = (food.calories * (item.quantity / 100.0));

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
                                    '${item.quantity.toStringAsFixed(0)} ${item.unit} • ${scaledP.toStringAsFixed(0)}g protein • ${scaledCals.toStringAsFixed(0)} kcal',
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
                              onPressed: () => _showEditPortionDialog(context, item),
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
                          FoodSearchSheet.show(context, mealId: meal.id, mealTitle: meal.name);
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
}
