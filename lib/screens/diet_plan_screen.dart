import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/nutrition_service.dart';
import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../widgets/common/app_bottom_sheet.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_chip.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_list_tile.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/section_header.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  late final NutritionService _nutritionService;
  late DailyNutrition _dailyNutrition;
  final TextEditingController _proteinInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nutritionService = AppDependencies.instance.nutritionService;
    _loadNutritionData();
  }

  void _loadNutritionData() {
    setState(() {
      _dailyNutrition = _nutritionService.getDailyNutrition();
      _proteinInputController.text = _dailyNutrition.totalProteinConsumed
          .toStringAsFixed(0);
    });
  }

  Future<void> _updateProtein(double newValue) async {
    await _nutritionService.saveProteinConsumed(newValue);
    _loadNutritionData();
  }

  Future<void> _toggleMeal(MealEntry meal) async {
    await _nutritionService.toggleMealCompletion(
      date: _dailyNutrition.date,
      mealId: meal.id,
    );
    _loadNutritionData();
  }

  void _showMealDetailsModal(MealEntry meal) {
    AppBottomSheet.show(
      context: context,
      title: meal.name,
      subtitle:
          '${meal.timeLabel} · ${meal.totalCalories.toStringAsFixed(0)} kcal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Items',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...meal.items.map((item) {
            return AppListTile(
              dense: true,
              leadingIcon: Icons.restaurant,
              title: item.name,
              subtitle:
                  '${item.servingSize} · ${item.calories.toStringAsFixed(0)} kcal',
              trailing: Text(
                'P:${item.proteinGrams.toStringAsFixed(0)}g C:${item.carbsGrams.toStringAsFixed(0)}g F:${item.fatGrams.toStringAsFixed(0)}g',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  color: AppColors.primary,
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          AppButton.primary(
            label: 'Add Food Item to ${meal.name}',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () {
              Navigator.pop(context);
              _showAddFoodBottomSheet();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _proteinInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final months = [
      'OCT',
      'NOV',
      'DEC',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[(now.month - 1) % 12]} ${now.day}';

    final caloriesGoal = _dailyNutrition.targets.calories;
    final caloriesConsumed = _dailyNutrition.totalCaloriesConsumed;
    final caloriesRemaining = _dailyNutrition.caloriesRemaining;
    final calorieProgress = (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: topInset + 16,
          bottom: bottomInset + 130,
          left: 16,
          right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader.standard(
              title: 'Diet & Nutrition Plan',
              subtitle: dateLabel,
              onNotificationsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              onSettingsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Daily Calorie Progress Ring Glass Card
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  ProgressRing.single(
                    size: 190,
                    progress: calorieProgress,
                    color: AppColors.primary,
                    strokeWidth: 14,
                    centerChild: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          caloriesConsumed.toStringAsFixed(0),
                          style: AppTheme.displayMetrics.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '/ ${caloriesGoal.toStringAsFixed(0)} kcal',
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.appSurfaceElevated,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${caloriesRemaining.toStringAsFixed(0)} kcal left',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Macros Progress Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'PROTEIN',
                          consumed: _dailyNutrition.totalProteinConsumed,
                          goal: _dailyNutrition.targets.proteinGrams,
                          unit: 'g',
                          color: AppColors.ringProtein,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'CARBS',
                          consumed: _dailyNutrition.totalCarbsConsumed,
                          goal: _dailyNutrition.targets.carbsGrams,
                          unit: 'g',
                          color: AppColors.ringStreak,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'FAT',
                          consumed: _dailyNutrition.totalFatConsumed,
                          goal: _dailyNutrition.targets.fatGrams,
                          unit: 'g',
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Meal Timeline Section Header & List
            const SectionHeader(
              title: 'Meal Timeline',
              subtitle: 'Daily protocol distribution & completion',
            ),
            const SizedBox(height: 14),

            ..._dailyNutrition.meals.map((meal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMealTimelineCard(context, meal),
              );
            }),

            const SizedBox(height: 16),

            // 4. Quick Protein Log Card
            _buildQuickProteinLogCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem({
    required BuildContext context,
    required String label,
    required double consumed,
    required double goal,
    required String unit,
    required Color color,
  }) {
    final progress = (consumed / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.appBackground,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${consumed.toStringAsFixed(0)}$unit',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '/ ${goal.toStringAsFixed(0)}$unit',
            style: AppTheme.bodySm.copyWith(
              fontSize: 10,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTimelineCard(BuildContext context, MealEntry meal) {
    final bool isCompleted = meal.isCompleted;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: isCompleted
          ? AppColors.primary.withValues(alpha: 0.4)
          : null,
      onTap: () => _showMealDetailsModal(meal),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion Checkbox Container with Scale-Bounce Micro Animation
          GestureDetector(
            onTap: () => _toggleMeal(meal),
            child: AnimatedScale(
              scale: isCompleted ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.primary
                      : context.appSurfaceElevated,
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.primary
                        : context.appOutlineVariant,
                    width: 1.5,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          key: ValueKey('check'),
                          color: AppColors.onPrimary,
                          size: 18,
                        )
                      : const Icon(
                          Icons.restaurant_outlined,
                          key: ValueKey('rest'),
                          color: AppColors.primary,
                          size: 16,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meal.name,
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    Text(
                      '${meal.totalCalories.toStringAsFixed(0)} kcal',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  meal.timeLabel,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Food Items Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: meal.items.map((item) {
                    return AppChip(
                      label: item.name,
                      variant: AppChipVariant.subtle,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'P: ${meal.totalProtein.toStringAsFixed(0)}g · C: ${meal.totalCarbs.toStringAsFixed(0)}g · F: ${meal.totalFat.toStringAsFixed(0)}g',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickProteinLogCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Log Protein Intake',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proteinInputController,
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Protein Consumed (g)',
                    labelStyle: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: context.appSurfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.appOutlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.appOutlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AppButton.primary(
                label: 'Save',
                isFullWidth: false,
                onPressed: () {
                  final val = double.tryParse(
                    _proteinInputController.text.trim(),
                  );
                  if (val != null) {
                    _updateProtein(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Protein intake updated successfully!'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddFoodBottomSheet() {
    final foodNameController = TextEditingController();
    final calController = TextEditingController(text: '250');
    final proController = TextEditingController(text: '30');
    final carbsController = TextEditingController(text: '15');
    final fatController = TextEditingController(text: '5');
    final MealCategory selectedCategory = MealCategory.snack;

    AppBottomSheet.show(
      context: context,
      title: 'Log Food Item',
      subtitle: 'Add a new food item to your nutrition plan',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: foodNameController,
            style: AppTheme.bodySm.copyWith(color: context.appTextPrimary),
            decoration: InputDecoration(
              labelText: 'Food Name',
              hintText: 'e.g. Whey Protein Scoop',
              filled: true,
              fillColor: context.appSurfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.appOutlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: calController,
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Calories',
                    filled: true,
                    fillColor: context.appSurfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.appOutlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: proController,
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Protein (g)',
                    filled: true,
                    fillColor: context.appSurfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.appOutlineVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppButton.primary(
            label: 'Add to Protocol',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () async {
              final name = foodNameController.text.trim();
              if (name.isNotEmpty) {
                final food = FoodItem(
                  id: 'food_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  calories: double.tryParse(calController.text) ?? 200,
                  proteinGrams: double.tryParse(proController.text) ?? 20,
                  carbsGrams: double.tryParse(carbsController.text) ?? 10,
                  fatGrams: double.tryParse(fatController.text) ?? 5,
                );

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                await _nutritionService.logFoodItem(
                  category: selectedCategory,
                  foodItem: food,
                );

                if (mounted) {
                  navigator.pop();
                  _loadNutritionData();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Added $name to Nutrition Plan!')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
