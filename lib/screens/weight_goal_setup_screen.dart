import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/weight_goal.dart';
import '../services/weight_goal_service.dart';
import '../repositories/weight_goal_repository.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import 'weight_gain_plan_screen.dart';

/// Multi-step setup wizard for creating or adjusting an AI-powered Weight Goal & Nutrition Program.
class WeightGoalSetupScreen extends StatefulWidget {
  final WeightGoal? initialGoal;

  const WeightGoalSetupScreen({super.key, this.initialGoal});

  @override
  State<WeightGoalSetupScreen> createState() => _WeightGoalSetupScreenState();
}

class _WeightGoalSetupScreenState extends State<WeightGoalSetupScreen> {
  final WeightGoalService _goalService = const WeightGoalService();
  final WeightGoalRepository _goalRepository =
      const LocalWeightGoalRepository();

  int _currentStep = 0;
  static const int _totalSteps = 6;

  // Form Fields State
  double _currentWeight = 55.0;
  double _targetWeight = 70.0;
  WeightGoalType _goalType = WeightGoalType.gain;
  int _targetWeeks = 24; // 6 months default
  DietPreference _diet = DietPreference.nonVegetarian;
  MealFrequency _mealsPerDay = MealFrequency.fourMeals;
  BudgetTier _budget = BudgetTier.medium;

  @override
  void initState() {
    super.initState();
    if (widget.initialGoal != null) {
      final g = widget.initialGoal!;
      _currentWeight = g.currentWeight;
      _targetWeight = g.targetWeight;
      _goalType = g.type;
      _targetWeeks = g.targetWeeks;
      _diet = g.diet;
      _mealsPerDay = g.mealsPerDay;
      _budget = g.budget;
    } else {
      final existing = _goalRepository.getWeightGoal();
      if (existing != null) {
        _currentWeight = existing.currentWeight;
        _targetWeight = existing.targetWeight;
        _goalType = existing.type;
        _targetWeeks = existing.targetWeeks;
        _diet = existing.diet;
        _mealsPerDay = existing.mealsPerDay;
        _budget = existing.budget;
      }
    }
  }

  WeightGoal _computeLiveGoal() {
    return _goalService.createWeightGoal(
      userId: 'user_01',
      currentWeight: _currentWeight,
      targetWeight: _targetWeight,
      targetWeeks: _targetWeeks,
      type: _goalType,
      diet: _diet,
      mealsPerDay: _mealsPerDay,
      budget: _budget,
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _saveAndComplete();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveAndComplete() async {
    final calculatedGoal = _computeLiveGoal();
    await _goalRepository.saveWeightGoal(calculatedGoal);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Weight Goal Program saved! Target: ${calculatedGoal.dailyCalorieTarget.toStringAsFixed(0)} kcal/day',
          style: AppTheme.bodySm.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WeightGainPlanScreen(goal: calculatedGoal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: _previousStep,
        ),
        title: Text(
          'Weight Goal Setup',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressBar(context),
            const SizedBox(height: 12),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildCurrentStepContent(context),
              ),
            ),

            // Navigation Buttons Bottom Bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Completed',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appSurfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildStep1CurrentWeight(context);
      case 1:
        return _buildStep2GoalObjective(context);
      case 2:
        return _buildStep3TargetWeight(context);
      case 3:
        return _buildStep4Timeline(context);
      case 4:
        return _buildStep5Preferences(context);
      case 5:
      default:
        return _buildStep6Summary(context);
    }
  }

  // --- STEP 1: Current Weight ---
  Widget _buildStep1CurrentWeight(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'What is your current weight?',
          subtitle:
              'This will be the baseline for your custom caloric calculations.',
        ),
        const SizedBox(height: 24),
        Center(
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currentWeight.toStringAsFixed(1),
                      style: AppTheme.displayMetrics.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kg',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Slider(
                  value: _currentWeight,
                  min: 40.0,
                  max: 160.0,
                  divisions: 240,
                  activeColor: AppColors.primary,
                  inactiveColor: context.appOutlineVariant,
                  onChanged: (val) => setState(() => _currentWeight = val),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickAdjustButton(
                      label: '- 0.5 kg',
                      onPressed: () => setState(
                        () => _currentWeight = (_currentWeight - 0.5).clamp(
                          40.0,
                          160.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAdjustButton(
                      label: '+ 0.5 kg',
                      onPressed: () => setState(
                        () => _currentWeight = (_currentWeight + 0.5).clamp(
                          40.0,
                          160.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: Goal Objective ---
  Widget _buildStep2GoalObjective(BuildContext context) {
    final goals = [
      {
        'type': WeightGoalType.gain,
        'title': 'Gain Weight / Lean Bulk',
        'desc': 'Build lean muscle mass with a calibrated caloric surplus.',
        'icon': Icons.fitness_center_rounded,
        'emoji': '💪',
      },
      {
        'type': WeightGoalType.lose,
        'title': 'Lose Fat / Cut',
        'desc': 'Drop body fat while preserving your hard-earned muscle.',
        'icon': Icons.local_fire_department_rounded,
        'emoji': '🔥',
      },
      {
        'type': WeightGoalType.maintain,
        'title': 'Maintain Weight',
        'desc': 'Optimize body composition and maintain steady body weight.',
        'icon': Icons.balance_rounded,
        'emoji': '⚖',
      },
      {
        'type': WeightGoalType.recomposition,
        'title': 'Body Recomposition',
        'desc': 'Simultaneously shed fat and build lean tissue at maintenance.',
        'icon': Icons.auto_awesome_rounded,
        'emoji': '🏆',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'What is your primary goal?',
          subtitle:
              'Select the transformation path that matches your ambition.',
        ),
        const SizedBox(height: 16),
        for (final item in goals) ...[
          _buildGoalOptionCard(
            context,
            type: item['type'] as WeightGoalType,
            title: item['title'] as String,
            desc: item['desc'] as String,
            icon: item['icon'] as IconData,
            emoji: item['emoji'] as String,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildGoalOptionCard(
    BuildContext context, {
    required WeightGoalType type,
    required String title,
    required String desc,
    required IconData icon,
    required String emoji,
  }) {
    final isSelected = _goalType == type;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _goalType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withValues(
                  alpha: isDark ? 0.25 : 0.12,
                )
              : context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appOutlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : context.appOutlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  // --- STEP 3: Target Weight ---
  Widget _buildStep3TargetWeight(BuildContext context) {
    final delta = _targetWeight - _currentWeight;
    final isGain = delta >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'What is your target weight?',
          subtitle: 'Define the milestone weight you want to reach.',
        ),
        const SizedBox(height: 24),
        Center(
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _targetWeight.toStringAsFixed(1),
                      style: AppTheme.displayMetrics.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kg',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isGain ? '+' : ''}${delta.toStringAsFixed(1)} kg transformation delta',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: _targetWeight,
                  min: 40.0,
                  max: 160.0,
                  divisions: 240,
                  activeColor: AppColors.primary,
                  inactiveColor: context.appOutlineVariant,
                  onChanged: (val) => setState(() => _targetWeight = val),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickAdjustButton(
                      label: '- 0.5 kg',
                      onPressed: () => setState(
                        () => _targetWeight = (_targetWeight - 0.5).clamp(
                          40.0,
                          160.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAdjustButton(
                      label: '+ 0.5 kg',
                      onPressed: () => setState(
                        () => _targetWeight = (_targetWeight + 0.5).clamp(
                          40.0,
                          160.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 4: Timeline ---
  Widget _buildStep4Timeline(BuildContext context) {
    final options = [
      {'weeks': 12, 'label': '3 Months', 'sub': 'Aggressive pace'},
      {'weeks': 24, 'label': '6 Months', 'sub': 'Recommended for lean mass'},
      {'weeks': 48, 'label': '12 Months', 'sub': 'Sustainable long-term bulk'},
    ];

    final weeklyRate = ((_targetWeight - _currentWeight).abs() / _targetWeeks)
        .toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'What is your target timeline?',
          subtitle: 'Choose how long you want to dedicate to this program.',
        ),
        const SizedBox(height: 16),
        for (final opt in options) ...[
          _buildTimelineCard(
            context,
            weeks: opt['weeks'] as int,
            label: opt['label'] as String,
            sub: opt['sub'] as String,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          borderColor: AppColors.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Velocity: ~$weeklyRate kg/week',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scientifically calibrated to maximize muscle synthesis and minimize fat.',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(
    BuildContext context, {
    required int weeks,
    required String label,
    required String sub,
  }) {
    final isSelected = _targetWeeks == weeks;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _targetWeeks = weeks),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withValues(
                  alpha: isDark ? 0.25 : 0.12,
                )
              : context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appOutlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : context.appTextSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label ($weeks weeks)',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 5: Preferences (Diet, Meals, Budget) ---
  Widget _buildStep5Preferences(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Dietary Preferences & Frequency',
          subtitle: 'Customize how your daily meal plan will be crafted.',
        ),
        const SizedBox(height: 20),

        // Diet Preference
        Text(
          'DIET PREFERENCE',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DietPreference.values.map((d) {
            final isSelected = _diet == d;
            return ChoiceChip(
              label: Text(d.displayName),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: context.appSurfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : context.appTextPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _diet = d),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Meal Frequency
        Text(
          'MEALS PER DAY',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealFrequency.values.map((m) {
            final isSelected = _mealsPerDay == m;
            return ChoiceChip(
              label: Text(m.displayName),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: context.appSurfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : context.appTextPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _mealsPerDay = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Budget Tier
        Text(
          'GROCERY & MEAL BUDGET',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BudgetTier.values.map((b) {
            final isSelected = _budget == b;
            return ChoiceChip(
              label: Text(b.displayName),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: context.appSurfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : context.appTextPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _budget = b),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 6: Summary & Confirmation ---
  Widget _buildStep6Summary(BuildContext context) {
    final liveGoal = _computeLiveGoal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Your Transformation Blueprint',
          subtitle:
              'Here is your scientifically calculated daily nutrition target.',
        ),
        const SizedBox(height: 20),

        // Main Target Calories Banner
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'DAILY TARGET CALORIES',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    liveGoal.dailyCalorieTarget.toStringAsFixed(0),
                    style: AppTheme.displayMetrics.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'kcal / day',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 16,
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
                    child: _buildMacroPill(
                      context,
                      label: 'PROTEIN',
                      value: '${liveGoal.proteinGrams.toStringAsFixed(0)}g',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroPill(
                      context,
                      label: 'CARBS',
                      value: '${liveGoal.carbsGrams.toStringAsFixed(0)}g',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroPill(
                      context,
                      label: 'FATS',
                      value: '${liveGoal.fatGrams.toStringAsFixed(0)}g',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary Specs Card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSpecRow(context, 'Objective', liveGoal.type.displayName),
              const Divider(height: 16),
              _buildSpecRow(
                context,
                'Transformation',
                '${liveGoal.currentWeight.toStringAsFixed(1)} kg → ${liveGoal.targetWeight.toStringAsFixed(1)} kg',
              ),
              const Divider(height: 16),
              _buildSpecRow(
                context,
                'Timeline',
                '${liveGoal.targetWeeks} weeks (~${liveGoal.expectedWeeklyRateKg.toStringAsFixed(2)} kg/wk)',
              ),
              const Divider(height: 16),
              _buildSpecRow(
                context,
                'Diet Preference',
                liveGoal.diet.displayName,
              ),
              const Divider(height: 16),
              _buildSpecRow(
                context,
                'Meal Schedule',
                liveGoal.mealsPerDay.displayName,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

  Widget _buildSpecRow(BuildContext context, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.bodySm.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
              fontSize: 13,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.headlineLg.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTheme.bodySm.copyWith(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAdjustButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: context.appOutlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: AppTheme.bodySm.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimary,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLastStep = _currentStep == _totalSteps - 1;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.primaryContainer.withValues(alpha: 0.2)
                : AppColors.secondary.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: context.appOutlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: AppTheme.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: AppButton.primary(
              label: isLastStep ? 'Save & Start Program' : 'Continue',
              icon: isLastStep
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _nextStep,
            ),
          ),
        ],
      ),
    );
  }
}
