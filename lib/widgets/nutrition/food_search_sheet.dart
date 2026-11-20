import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/food_item.dart';
import '../../models/nutrient_format.dart';
import '../../providers/fitness_provider.dart';
import '../../services/nutrition/nutrition_calculator.dart';
import 'custom_food_modal.dart';
import 'food_result_parts.dart';
import '../../screens/unified_food_scanner_screen.dart';

/// Reusable Modal Bottom Sheet for searching, portion scaling, and adding foods to meals
class FoodSearchSheet extends StatefulWidget {
  final String mealId;
  final String mealTitle;

  const FoodSearchSheet({
    super.key,
    required this.mealId,
    required this.mealTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String mealId,
    required String mealTitle,
  }) {
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
  String _selectedCategory = 'All';
  late String _selectedMealId;
  late String _selectedMealTitle;

  final List<String> _mealOptions = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  final List<String> _categories = [
    'All',
    'Favorites',
    'Recent',
    'Protein',
    'Fruits',
    'Vegetables',
    'Grains',
    'Indian',
    'Mizo',
    'Fast Food',
    'Snacks',
    'Drinks',
    'Desserts',
    'Packaged',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMealId = widget.mealId.isNotEmpty ? widget.mealId : 'Breakfast';
    _selectedMealTitle = widget.mealTitle.isNotEmpty
        ? widget.mealTitle
        : 'Breakfast';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FoodItem> _getFilteredFoods(FitnessProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    List<FoodItem> foods;

    if (_selectedCategory == 'Favorites') {
      foods = provider.favoriteFoods;
    } else if (_selectedCategory == 'Recent') {
      foods = provider.recentFoods;
    } else if (_selectedCategory == 'Custom') {
      foods = provider.availableFoods.where((f) => f.isCustom).toList();
    } else if (_selectedCategory == 'Packaged') {
      foods = provider.availableFoods.where((f) => f.isPackaged).toList();
    } else if (_selectedCategory == 'All') {
      foods = provider.availableFoods;
    } else {
      foods = provider.searchFoods('', _selectedCategory);
    }

    if (query.isEmpty) return foods;

    return foods.where((food) {
      final nameMatch = food.name.toLowerCase().contains(query);
      final brandMatch = food.brand?.toLowerCase().contains(query) ?? false;
      final categoryMatch = food.category.toLowerCase().contains(query);
      final altMatch = food.altNames.any(
        (alt) => alt.toLowerCase().contains(query),
      );
      return nameMatch || brandMatch || categoryMatch || altMatch;
    }).toList();
  }

  String _getFoodEmoji(String name, String category) {
    final n = name.toLowerCase();
    if (n.contains('chicken')) return '🍗';
    if (n.contains('egg')) return '🥚';
    if (n.contains('whey') || n.contains('protein') || n.contains('shake')) {
      return '🥤';
    }
    if (n.contains('apple')) return '🍎';
    if (n.contains('banana')) return '🍌';
    if (n.contains('rice') || n.contains('biryani')) return '🍚';
    if (n.contains('paneer') || n.contains('cheese')) return '🧀';
    if (n.contains('fish') || n.contains('salmon') || n.contains('tuna')) {
      return '🐟';
    }
    if (n.contains('burger')) return '🍔';
    if (n.contains('pizza')) return '🍕';
    if (n.contains('coffee')) return '☕';
    if (n.contains('tea')) return '🍵';
    if (category.toLowerCase() == 'fruits') return '🍎';
    if (category.toLowerCase() == 'drinks') return '🥤';
    if (category.toLowerCase() == 'vegetables') return '🥦';
    return '🥗';
  }

  void _openPortionSelector(FoodItem food) {
    PortionSelectorSheet.show(
      context,
      food: food,
      currentMealId: _selectedMealId,
      currentMealTitle: _selectedMealTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final filteredFoods = _getFilteredFoods(provider);
        final recentFoods = provider.recentFoods;
        final favoriteFoods = provider.favoriteFoods;

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.appCardBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appOutlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Bar & Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADD FOOD',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? AppColors.primaryContainer
                                  : AppColors.primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search catalogue, scan meals, or enter nutrition',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Choose Meal Selector Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'Meal:',
                      style: AppTheme.bodySm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _mealOptions.map((meal) {
                            final isSel =
                                _selectedMealTitle.toLowerCase() ==
                                meal.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(meal),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedMealTitle = meal;
                                    _selectedMealId = meal;
                                  });
                                },
                                selectedColor: AppColors.primaryContainer,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSel
                                      ? Colors.black
                                      : context.appTextPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Quick Actions Row: [📷 Scan Food] [🔳 Scan Barcode] [✏ Manual Entry]
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        icon: Icons.camera_alt_rounded,
                        title: 'Scan Food',
                        subtitle: 'AI Photo',
                        onTap: () {
                          UnifiedFoodScannerScreen.show(
                            context,
                            initialMode: UnifiedScanMode.foodAi,
                            currentMealId: _selectedMealId,
                            currentMealTitle: _selectedMealTitle,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan Barcode',
                        subtitle: 'QR / UPC',
                        onTap: () {
                          UnifiedFoodScannerScreen.show(
                            context,
                            initialMode: UnifiedScanMode.barcode,
                            currentMealId: _selectedMealId,
                            currentMealTitle: _selectedMealTitle,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        icon: Icons.edit_note_rounded,
                        title: 'Manual Entry',
                        subtitle: 'Custom Food',
                        onTap: () => CustomFoodModal.show(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search food, brand, or category...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryContainer,
                    ),
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
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

              // Category Filter Chips (Horizontally Scrollable)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : context.appTextPrimary,
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Recent Foods Horizontal Bar (if searching 'All' or 'Recent' and search is empty)
              if (recentFoods.isNotEmpty &&
                  (_selectedCategory == 'All' ||
                      _selectedCategory == 'Recent') &&
                  _searchController.text.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECENT FOODS',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: recentFoods.take(6).map((food) {
                            final emoji = _getFoodEmoji(
                              food.name,
                              food.category,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => _openPortionSelector(food),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1F222B)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.appOutlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        food.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 14,
                                        color: AppColors.primaryContainer,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Favorites Section (if searching 'All' or 'Favorites' and search is empty)
              if (favoriteFoods.isNotEmpty &&
                  (_selectedCategory == 'All' ||
                      _selectedCategory == 'Favorites') &&
                  _searchController.text.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAVORITE FOODS',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: favoriteFoods.take(6).map((food) {
                            final emoji = _getFoodEmoji(
                              food.name,
                              food.category,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => _openPortionSelector(food),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        food.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.favorite_rounded,
                                        size: 12,
                                        color: Colors.redAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Food Results List
              Expanded(
                child: filteredFoods.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No matching foods found',
                              style: AppTheme.bodySm.copyWith(
                                color: context.appTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => CustomFoodModal.show(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('+ Create Custom Food'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryContainer,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        itemCount: filteredFoods.length,
                        itemBuilder: (context, index) {
                          final food = filteredFoods[index];
                          final isFav = provider.isFavoriteFood(food.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1B1D24)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.appOutlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () => _openPortionSelector(food),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      // Food Emoji Avatar
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors
                                            .primaryContainer
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          _getFoodEmoji(
                                            food.name,
                                            food.category,
                                          ),
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Title & Badges & Macros Summary
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Name + Badges
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    food.name,
                                                    style: AppTheme.headlineMd
                                                        .copyWith(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: context
                                                              .appTextPrimary,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (food.isCustom) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'CUSTOM',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (food.isPackaged) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'PACKAGED',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color:
                                                            Colors.purpleAccent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (food.brand != null &&
                                                    food.brand!.isNotEmpty) ...[
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        food.brand!,
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              Colors.blueAccent,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),

                                            // Nutrition Summary (Calories, Protein, Carbs, Fat)
                                            Text(
                                              '${NutrientFormat.kcal(food.valueOf(FoodItem.calorieKey), food.statusOf(FoodItem.calorieKey))}  •  ${_macroText(food, FoodItem.proteinKey)} Protein  •  ${_macroText(food, FoodItem.carbohydrateKey)} Carbs  •  ${_macroText(food, FoodItem.fatKey)} Fat',
                                              style: AppTheme.bodySm.copyWith(
                                                fontSize: 11,
                                                color: context.appTextSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Action Buttons: Favorite Heart & Separate Add + Button
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isFav
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                        .favorite_outline_rounded,
                                              color: isFav
                                                  ? Colors.redAccent
                                                  : context.appTextSecondary,
                                              size: 20,
                                            ),
                                            onPressed: () => provider
                                                .toggleFavoriteFood(food.id),
                                            tooltip: isFav
                                                ? 'Remove Favorite'
                                                : 'Favorite Food',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_rounded,
                                              color: AppColors.primaryContainer,
                                              size: 24,
                                            ),
                                            onPressed: () =>
                                                _openPortionSelector(food),
                                            tooltip: 'Add Food',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1D24) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryContainer.withValues(
              alpha: isDark ? 0.3 : 0.4,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryContainer, size: 22),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Food Detail & Portion Selector Bottom Sheet Modal
class PortionSelectorSheet extends StatefulWidget {
  final FoodItem food;
  final String currentMealId;
  final String currentMealTitle;

  const PortionSelectorSheet({
    super.key,
    required this.food,
    required this.currentMealId,
    required this.currentMealTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required FoodItem food,
    required String currentMealId,
    required String currentMealTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PortionSelectorSheet(
        food: food,
        currentMealId: currentMealId,
        currentMealTitle: currentMealTitle,
      ),
    );
  }

  @override
  State<PortionSelectorSheet> createState() => _PortionSelectorSheetState();
}

class _PortionSelectorSheetState extends State<PortionSelectorSheet> {
  late final TextEditingController _quantityController;
  late String _selectedUnit;
  late double _quantity;
  late String _selectedMealId;
  late String _selectedMealTitle;

  final List<String> _units = [
    'g',
    'kg',
    'ml',
    'L',
    'piece',
    'serving',
    'cup',
    'slice',
    'bowl',
    'package',
    'packet',
    'bottle',
    'can',
  ];

  /// Units this food can be logged in: a per-100 g food has no volume units
  /// and a per-100 ml food has no weight units (never interchangeable).
  List<String> get _availableUnits => _units
      .where((u) => NutritionCalculator.isUnitCompatible(widget.food, u))
      .toList();

  final Map<String, String> _meals = {
    'Breakfast': 'Breakfast',
    'Lunch': 'Lunch',
    'Dinner': 'Dinner',
    'Snacks': 'Snack',
  };

  @override
  void initState() {
    super.initState();
    final available = _availableUnits;
    _selectedUnit =
        widget.food.servingUnit.isNotEmpty &&
            available.contains(widget.food.servingUnit)
        ? widget.food.servingUnit
        : available.first;

    final numericMatch = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(widget.food.servingSize);
    if (numericMatch != null) {
      _quantity = double.tryParse(numericMatch.group(1)!) ?? 100.0;
    } else {
      _quantity = 100.0;
    }
    // Values for one serving or one package start at one of those.
    if (widget.food.nutritionBasis == NutritionBasis.perServing) {
      _selectedUnit = 'serving';
      _quantity = 1.0;
    } else if (widget.food.nutritionBasis == NutritionBasis.perPackage) {
      _selectedUnit = 'package';
      _quantity = 1.0;
    }
    _quantityController = TextEditingController(
      text: _quantity == _quantity.toInt()
          ? _quantity.toInt().toString()
          : _quantity.toStringAsFixed(1),
    );

    _selectedMealTitle = widget.currentMealTitle.isNotEmpty
        ? widget.currentMealTitle
        : 'Breakfast';
    _selectedMealId = widget.currentMealId.isNotEmpty
        ? widget.currentMealId
        : 'Breakfast';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(double newQty) {
    if (newQty <= 0) return;
    setState(() {
      _quantity = newQty;
      _quantityController.text = _quantity == _quantity.toInt()
          ? _quantity.toInt().toString()
          : _quantity.toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;

    final scaled = NutritionCalculator.calculateNutrition(
      widget.food,
      _quantity,
      _selectedUnit,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appOutlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Food Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.food.name,
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.food.brand != null &&
                              widget.food.brand!.isNotEmpty)
                            Text(
                              'Brand: ${widget.food.brand}',
                              style: AppTheme.bodySm.copyWith(
                                color: AppColors.primaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Scaled Nutrition Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F222B)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calories',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.appTextSecondary,
                            ),
                          ),
                          Text(
                            widget.food.isNutrientKnown(FoodItem.calorieKey)
                                ? '${scaled.calories.toStringAsFixed(0)} kcal'
                                : '— kcal',
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroItem(
                            context,
                            'Protein',
                            widget.food.isNutrientKnown(FoodItem.proteinKey)
                                ? '${scaled.protein.toStringAsFixed(1)}g'
                                : '—',
                            AppColors.primaryContainer,
                          ),
                          _buildMacroItem(
                            context,
                            'Carbs',
                            widget.food.isNutrientKnown(
                                  FoodItem.carbohydrateKey,
                                )
                                ? '${scaled.carbohydrates.toStringAsFixed(1)}g'
                                : '—',
                            Colors.blueAccent,
                          ),
                          _buildMacroItem(
                            context,
                            'Fat',
                            widget.food.isNutrientKnown(FoodItem.fatKey)
                                ? '${scaled.fats.toStringAsFixed(1)}g'
                                : '—',
                            Colors.orangeAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Serving Selector Title
                Text(
                  'SERVING SIZE & PORTION',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Portion Selector: [-] [Quantity Input] [+] [Unit Dropdown]
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () {
                        final step =
                            (_selectedUnit == 'g' || _selectedUnit == 'ml')
                            ? 10.0
                            : 1.0;
                        _updateQuantity((_quantity - step).clamp(1.0, 10000.0));
                      },
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        onChanged: (val) {
                          final q = double.tryParse(val) ?? 100.0;
                          setState(() {
                            _quantity = q;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () {
                        final step =
                            (_selectedUnit == 'g' || _selectedUnit == 'ml')
                            ? 10.0
                            : 1.0;
                        _updateQuantity(_quantity + step);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(width: 12),

                    // Unit Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUnit,
                          items: _availableUnits
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUnit = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Meal Target Selector
                Row(
                  children: [
                    Text(
                      'Target Meal:',
                      style: AppTheme.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _meals.keys.map((mealLabel) {
                            final isSel =
                                _selectedMealTitle.toLowerCase() ==
                                mealLabel.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(mealLabel),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedMealTitle = mealLabel;
                                    _selectedMealId = _meals[mealLabel]!;
                                  });
                                },
                                selectedColor: AppColors.primaryContainer,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSel
                                      ? Colors.black
                                      : context.appTextPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Add to Meal Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Unknown calories are never logged as a quiet 0 kcal.
                      if (widget.food.caloriesUnknown) {
                        final ok = await confirmLogUnknownCalories(
                          context,
                          widget.food.name,
                        );
                        if (!ok || !context.mounted) return;
                      }
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await provider.addFoodToMeal(
                        _selectedMealId,
                        widget.food,
                        _quantity,
                        _selectedUnit,
                      );
                      if (mounted) {
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${widget.food.name} (${_quantity.toStringAsFixed(0)}$_selectedUnit) to $_selectedMealTitle',
                            ),
                            backgroundColor: AppColors.primaryContainer,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'ADD TO ${_selectedMealTitle.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// A macro in the search list: its amount, a "~" estimate, or a dash when the
/// food has no value (never a 0 made up from a missing one).
String _macroText(FoodItem food, String nutrient) => NutrientFormat.grams(
  food.valueOf(nutrient),
  food.statusOf(nutrient),
  digits: 0,
);
