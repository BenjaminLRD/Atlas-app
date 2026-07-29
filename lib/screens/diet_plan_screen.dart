import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/nutrition_service.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/section_header.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  late final NutritionService _nutritionService;

  final double _caloriesConsumed = 1850.0;
  final double _caloriesGoal = 2500.0;

  double _proteinConsumed = 120.0;
  double _proteinGoal = 160.0;

  final double _carbsConsumed = 210.0;
  final double _carbsGoal = 350.0;

  final double _fatConsumed = 65.0;
  final double _fatGoal = 75.0;

  final TextEditingController _proteinInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nutritionService = AppDependencies.instance.nutritionService;
    _loadNutritionData();
  }

  void _loadNutritionData() {
    setState(() {
      _proteinConsumed = _nutritionService.getProteinConsumed();
      _proteinGoal = _nutritionService.getProteinGoal();
      _proteinInputController.text = _proteinConsumed.toStringAsFixed(0);
    });
  }

  Future<void> _updateProtein(double newValue) async {
    await _nutritionService.saveProteinConsumed(newValue);
    setState(() {
      _proteinConsumed = newValue;
    });
  }

  @override
  void dispose() {
    _proteinInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caloriesRemaining = (_caloriesGoal - _caloriesConsumed).clamp(0.0, _caloriesGoal);
    final calorieProgress = (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 56, bottom: 120, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FRIDAY, OCT 27',
                      style: AppTheme.labelCaps.copyWith(color: context.appTextSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('Diet & Nutrition Plan', style: AppTheme.headlineLgMobile.copyWith(color: context.appTextPrimary)),
                  ],
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Daily Calorie Ring Card
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  ProgressRing.single(
                    size: 200,
                    progress: calorieProgress,
                    color: context.appPrimary,
                    strokeWidth: 14,
                    centerChild: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _caloriesConsumed.toStringAsFixed(0),
                          style: AppTheme.displayMetrics.copyWith(
                            fontSize: 38,
                            color: context.appPrimary,
                          ),
                        ),
                        Text(
                          '/ ${_caloriesGoal.toStringAsFixed(0)} kcal',
                          style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.appSurfaceElevated,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${caloriesRemaining.toStringAsFixed(0)} kcal left',
                            style: AppTheme.labelCaps.copyWith(fontSize: 11, color: context.appTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Macros Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'Protein',
                          consumed: _proteinConsumed,
                          goal: _proteinGoal,
                          unit: 'g',
                          color: AppColors.ringProtein,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'Carbs',
                          consumed: _carbsConsumed,
                          goal: _carbsGoal,
                          unit: 'g',
                          color: AppColors.ringStreak,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMacroItem(
                          context: context,
                          label: 'Fat',
                          consumed: _fatConsumed,
                          goal: _fatGoal,
                          unit: 'g',
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Meal Timeline Section
            const SectionHeader(
              title: 'Meal Timeline',
              subtitle: 'Daily protocol distribution',
            ),
            const SizedBox(height: 16),

            _buildMealTimelineNode(
              context: context,
              title: 'Breakfast',
              time: '8:00 AM',
              calories: '620 kcal',
              items: ['Oatmeal', 'Eggs', 'Banana'],
              macros: 'P: 35g · C: 80g · F: 12g',
              isCompleted: true,
            ),
            const SizedBox(height: 14),

            _buildMealTimelineNode(
              context: context,
              title: 'Lunch',
              time: '1:00 PM',
              calories: '750 kcal',
              items: ['Grilled Chicken Breast', 'Brown Rice', 'Steamed Veggies'],
              macros: 'P: 55g · C: 90g · F: 18g',
              isCurrent: true,
            ),
            const SizedBox(height: 14),

            _buildMealTimelineNode(
              context: context,
              title: 'Snack',
              time: '4:00 PM',
              calories: '250 kcal',
              items: ['Whey Protein Shake', 'Almonds'],
              macros: 'P: 30g · C: 10g · F: 10g',
              isFuture: true,
            ),
            const SizedBox(height: 14),

            _buildMealTimelineNode(
              context: context,
              title: 'Dinner',
              time: '7:30 PM',
              calories: '580 kcal',
              items: ['Salmon Filet', 'Sweet Potato'],
              macros: 'P: 40g · C: 50g · F: 15g',
              isFuture: true,
            ),
            const SizedBox(height: 32),

            // Quick Protein Quick Log Widget
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Log Protein Intake', style: AppTheme.headlineMd.copyWith(fontSize: 18, color: context.appTextPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proteinInputController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Protein Consumed (grams)',
                            filled: true,
                            fillColor: context.appSurfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Save',
                        onPressed: () {
                          final val = double.tryParse(_proteinInputController.text.trim());
                          if (val != null) {
                            _updateProtein(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Protein goal updated successfully!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appOutlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.appSurfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 11, color: context.appTextSecondary)),
          const SizedBox(height: 2),
          Text(
            '${consumed.toStringAsFixed(0)}$unit',
            style: AppTheme.headlineMd.copyWith(fontSize: 16, color: color),
          ),
          Text(
            '/ ${goal.toStringAsFixed(0)}$unit',
            style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTimelineNode({
    required BuildContext context,
    required String title,
    required String time,
    required String calories,
    required List<String> items,
    required String macros,
    bool isCompleted = false,
    bool isCurrent = false,
    bool isFuture = false,
  }) {
    Color iconBg = context.appSurfaceElevated;
    IconData icon = Icons.circle_outlined;
    Color iconColor = context.appTextSecondary;

    if (isCompleted) {
      iconBg = context.appPrimary;
      icon = Icons.check_rounded;
      iconColor = AppColors.onPrimary;
    } else if (isCurrent) {
      iconBg = AppColors.primaryContainer;
      icon = Icons.restaurant_rounded;
      iconColor = AppColors.onPrimaryContainer;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: isCurrent
                ? context.appSurface
                : (isFuture ? context.appSurfaceContainerLow.withValues(alpha: 0.5) : null),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTheme.headlineMd.copyWith(fontSize: 17, color: context.appTextPrimary)),
                    Text(calories, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700, color: context.appPrimary)),
                  ],
                ),
                Text(time, style: AppTheme.labelCaps.copyWith(fontSize: 11, color: context.appTextSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: items
                      .map((item) => Chip(
                            label: Text(item, style: AppTheme.bodySm.copyWith(fontSize: 12, color: context.appTextPrimary)),
                            backgroundColor: context.appSurfaceElevated.withValues(alpha: 0.6),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                Text(macros, style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
