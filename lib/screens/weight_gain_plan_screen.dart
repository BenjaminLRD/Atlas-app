import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/weight_goal.dart';
import '../services/weight_goal_service.dart';
import '../repositories/weight_goal_repository.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_header.dart';
import '../widgets/nutrition/food_search_sheet.dart';
import 'weight_goal_setup_screen.dart';
import 'ai_coach_screen.dart';

/// Central Hub for user's AI-Powered Weight Goal Transformation Program and Daily Meal Schedule
class WeightGainPlanScreen extends StatefulWidget {
  final WeightGoal? goal;

  const WeightGainPlanScreen({super.key, this.goal});

  @override
  State<WeightGainPlanScreen> createState() => _WeightGainPlanScreenState();
}

class _WeightGainPlanScreenState extends State<WeightGainPlanScreen> {
  final WeightGoalService _goalService = const WeightGoalService();
  final WeightGoalRepository _goalRepository =
      const LocalWeightGoalRepository();

  WeightGoal? _activeGoal;
  List<GeneratedMealPlanItem> _mealPlan = [];
  WeightGoalAdaptationResult? _adaptationResult;
  final double _mockCurrentWeighIn = 55.6; // Logged weight progress
  final int _weeksLogged = 2;

  @override
  void initState() {
    super.initState();
    _loadGoalData();
  }

  void _loadGoalData() {
    _activeGoal =
        widget.goal ??
        _goalRepository.getWeightGoal() ??
        WeightGoal.sampleGain();
    if (_activeGoal != null) {
      _mealPlan = _goalService.generateMealPlan(_activeGoal!);
      _adaptationResult = _goalService.analyzeProgressAndAdapt(
        goal: _activeGoal!,
        currentLoggedWeight: _mockCurrentWeighIn,
        weeksLogged: _weeksLogged,
      );
    }
  }

  void _applyCalorieAdjustment(WeightGoal updatedGoal) async {
    await _goalRepository.saveWeightGoal(updatedGoal);
    setState(() {
      _activeGoal = updatedGoal;
      _mealPlan = _goalService.generateMealPlan(updatedGoal);
      _adaptationResult = _goalService.analyzeProgressAndAdapt(
        goal: updatedGoal,
        currentLoggedWeight: _mockCurrentWeighIn,
        weeksLogged: _weeksLogged,
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Target updated to ${updatedGoal.dailyCalorieTarget.toStringAsFixed(0)} kcal/day!',
          style: AppTheme.bodySm.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final goal = _activeGoal;

    if (goal == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppHeader.standard(
          title: 'WEIGHT GOAL PROGRAM',
          subtitle: 'AI-Guided Mass & Nutrition Blueprint',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Weight Goal',
                  style: AppTheme.headlineMd.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your personalized transformation blueprint with tailored calorie surplus and meal plans.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton.primary(
                  label: 'Setup Weight Goal',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const WeightGoalSetupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'WEIGHT GOAL PROGRAM',
        subtitle: 'AI-Guided Mass & Nutrition Blueprint',
        trailing: IconButton(
          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
          tooltip: 'Edit Goal Parameters',
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => WeightGoalSetupScreen(initialGoal: goal),
                  ),
                )
                .then((_) {
                  setState(() => _loadGoalData());
                });
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Transformation Trajectory Header Card
              _buildTransformationHeaderCard(context, goal),
              const SizedBox(height: 16),

              // 2. Daily Caloric & Macro Targets Banner
              _buildDailyTargetBanner(context, goal),
              const SizedBox(height: 20),

              // 3. Progress Adaptation Alert (if applicable)
              if (_adaptationResult != null &&
                  _adaptationResult!.needsAdjustment) ...[
                _buildAdaptationCard(context, _adaptationResult!),
                const SizedBox(height: 20),
              ],

              // 4. Daily Meal Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "TODAY'S MEAL SCHEDULE",
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${goal.mealsPerDay.count} Meals • ${goal.diet.displayName}',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              for (final meal in _mealPlan) ...[
                _buildMealCard(context, meal),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 12),

              // 5. Ask AI Coach Action Banner
              AppCard(
                padding: const EdgeInsets.all(14),
                borderColor: AppColors.primary.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: isDark ? 0.3 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need meal alternatives or coaching?',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chat with your AI Coach for ingredient swaps, recipes, or routine adjustments.',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AICoachScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransformationHeaderCard(BuildContext context, WeightGoal goal) {
    final progress = goal.progressFraction(_mockCurrentWeighIn);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.type.displayName.toUpperCase(),
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${goal.targetWeeks} Weeks Plan',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Baseline',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                    Text(
                      '${goal.currentWeight.toStringAsFixed(1)} kg',
                      style: AppTheme.headlineLg.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target Goal',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                    Text(
                      '${goal.targetWeight.toStringAsFixed(1)} kg',
                      style: AppTheme.headlineLg.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appSurfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Weigh-In: ${_mockCurrentWeighIn.toStringAsFixed(1)} kg (+${(_mockCurrentWeighIn - goal.currentWeight).toStringAsFixed(1)} kg)',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}% Done',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTargetBanner(BuildContext context, WeightGoal goal) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DAILY TARGET INTAKE',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '~${goal.expectedWeeklyRateKg.toStringAsFixed(2)} kg/wk pace',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    goal.dailyCalorieTarget.toStringAsFixed(0),
                    style: AppTheme.displayMetrics.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'kcal / day',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMacroBox(
                  context,
                  title: 'PROTEIN',
                  grams: '${goal.proteinGrams.toStringAsFixed(0)}g',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroBox(
                  context,
                  title: 'CARBS',
                  grams: '${goal.carbsGrams.toStringAsFixed(0)}g',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroBox(
                  context,
                  title: 'FATS',
                  grams: '${goal.fatGrams.toStringAsFixed(0)}g',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBox(
    BuildContext context, {
    required String title,
    required String grams,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              grams,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptationCard(
    BuildContext context,
    WeightGoalAdaptationResult result,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_mode_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.message,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.recommendation,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ElevatedButton.icon(
                onPressed: () => _applyCalorieAdjustment(result.adjustedGoal),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: Text(
                  'Apply ${result.suggestedCalorieDelta > 0 ? '+' : ''}${result.suggestedCalorieDelta.toStringAsFixed(0)} kcal',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, GeneratedMealPlanItem meal) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meal.mealType.toUpperCase(),
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${meal.calories.toStringAsFixed(0)} kcal',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meal.title,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meal.description,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Ingredients bullets
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: meal.ingredients.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.appOutlineVariant),
                ),
                child: Text(
                  ing,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Macros + Log Meal Button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildMealMacroPill(
                    'P: ${meal.protein.toStringAsFixed(0)}g',
                    const Color(0xFF10B981),
                  ),
                  _buildMealMacroPill(
                    'C: ${meal.carbs.toStringAsFixed(0)}g',
                    const Color(0xFF3B82F6),
                  ),
                  _buildMealMacroPill(
                    'F: ${meal.fats.toStringAsFixed(0)}g',
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  FoodSearchSheet.show(
                    context,
                    mealId: 'meal_${meal.mealType.toLowerCase()}',
                    mealTitle: meal.mealType,
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Log Meal'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: context.appOutlineVariant),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealMacroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
