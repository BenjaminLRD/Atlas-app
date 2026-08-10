import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/food_item.dart';
import '../../providers/fitness_provider.dart';

/// Reusable Modal Bottom Sheet for searching and adding foods to a meal
class FoodSearchSheet extends StatefulWidget {
  final String mealId;
  final String mealTitle;

  const FoodSearchSheet({
    super.key,
    required this.mealId,
    required this.mealTitle,
  });

  static Future<void> show(BuildContext context, {required String mealId, required String mealTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FoodSearchSheet(mealId: mealId, mealTitle: mealTitle),
    );
  }

  @override
  State<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<FoodSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '100');
  String _selectedCategory = 'All';
  FoodItem? _selectedFood;
  String _selectedUnit = 'grams';

  final List<String> _categories = ['All', 'Protein', 'Carbohydrates', 'Fats'];

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  List<FoodItem> _getFilteredFoods() {
    final provider = FitnessProvider.instance;
    final query = _searchController.text.trim();
    final results = query.isEmpty ? provider.availableFoods : provider.searchFoods(query);

    if (_selectedCategory == 'All') return results;

    return results.where((item) {
      final cat = item.category.toLowerCase();
      final targetCat = _selectedCategory.toLowerCase();
      return cat.contains(targetCat);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final filteredFoods = _getFilteredFoods();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Sheet Drag Handle & Title
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appOutlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADD FOOD TO ${widget.mealTitle.toUpperCase()}',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Search Food Database',
                      style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search food name (e.g. Chicken, Rice)...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryContainer),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black : context.appTextPrimary,
                    ),
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Food List
          Expanded(
            child: filteredFoods.isEmpty
                ? Center(
                    child: Text(
                      'No matching foods found',
                      style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredFoods.length,
                    itemBuilder: (context, index) {
                      final food = filteredFoods[index];
                      final isSelected = _selectedFood?.id == food.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryContainer.withValues(alpha: isDark ? 0.15 : 0.1)
                              : (isDark ? const Color(0xFF1B1D24) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryContainer
                                : context.appOutlineVariant.withValues(alpha: 0.3),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            food.name,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${food.calories.toStringAsFixed(0)} kcal • ${food.protein.toStringAsFixed(0)}g P • ${food.carbohydrates.toStringAsFixed(0)}g C • ${food.fats.toStringAsFixed(0)}g F',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryContainer)
                              : const Icon(Icons.add_circle_outline_rounded),
                          onTap: () {
                            setState(() {
                              _selectedFood = food;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Portion & Add Section
          if (_selectedFood != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1D24) : Colors.grey.shade100,
                border: Border(
                  top: BorderSide(
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Portion Quantity',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedUnit,
                        items: const [
                          DropdownMenuItem(value: 'grams', child: Text('grams')),
                          DropdownMenuItem(value: 'servings', child: Text('servings')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedUnit = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final qty = double.tryParse(_quantityController.text) ?? 100.0;
                        await FitnessProvider.instance.addFoodToMeal(
                          widget.mealId,
                          _selectedFood!,
                          qty,
                          _selectedUnit,
                        );
                        if (mounted) {
                          navigator.pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ADD TO ${widget.mealTitle.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
