import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../data/local_storage.dart';
import '../../models/user_goal.dart';
import '../../providers/fitness_provider.dart';
import '../../services/goal_calculation_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../main.dart';

class GoalSummaryScreen extends StatefulWidget {
  final FitnessGoalType goalType;
  final FitnessLevel fitnessLevel;
  final ActivityLevel activityLevel;
  final int age;
  final double height;
  final double currentWeight;
  final double targetWeight;
  final GoalCalculationService calculationService;

  const GoalSummaryScreen({
    super.key,
    required this.goalType,
    required this.fitnessLevel,
    required this.activityLevel,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    this.calculationService = const GoalCalculationService(),
  });

  @override
  State<GoalSummaryScreen> createState() => _GoalSummaryScreenState();
}

class _GoalSummaryScreenState extends State<GoalSummaryScreen>
    with SingleTickerProviderStateMixin {
  bool _isGeneratingPlan = false;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onCreatePlanPressed() async {
    setState(() {
      _isGeneratingPlan = true;
    });

    // Simulated short animation for plan compilation experience
    await Future.delayed(const Duration(milliseconds: 1200));

    final generatedGoal = widget.calculationService.generateUserGoal(
      id: 'user_goal_${DateTime.now().millisecondsSinceEpoch}',
      goalType: widget.goalType,
      fitnessLevel: widget.fitnessLevel,
      activityLevel: widget.activityLevel,
      age: widget.age,
      height: widget.height,
      currentWeight: widget.currentWeight,
      targetWeight: widget.targetWeight,
    );

    await FitnessProvider.instance.saveGoal(generatedGoal);
    await LocalStorage.setGoalOnboardingCompleted(true);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.calculationService.calculateTargets(
      age: widget.age,
      height: widget.height,
      weight: widget.currentWeight,
      activityLevel: widget.activityLevel,
      goalType: widget.goalType,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Personalized Fitness Plan',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your inputs, we calculated your optimal daily caloric and macro targets.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),

          if (_isGeneratingPlan) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Generating Your Custom Protocol...',
                      style: AppTheme.headlineMd.copyWith(
                        color: context.appTextPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Setting up daily calories, protein, and progressive overload split.',
                      style: AppTheme.bodySm.copyWith(
                        color: context.appTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Daily Calorie Hero Card
            AppCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderColor: AppColors.primaryContainer,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY CALORIE TARGET',
                          style: AppTheme.labelCaps.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${targets.targetCalories.round()} kcal / day',
                          style: AppTheme.headlineLg.copyWith(
                            color: context.appTextPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Daily Macro Split',
              style: AppTheme.headlineMd.copyWith(color: context.appTextPrimary),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMacroCard(
                    context: context,
                    label: 'Protein',
                    value: '${targets.targetProtein.round()}g',
                    subtitle: 'Muscle Repair',
                    icon: Icons.egg_alt_rounded,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMacroCard(
                    context: context,
                    label: 'Carbs',
                    value: '${targets.targetCarbohydrates.round()}g',
                    subtitle: 'Workout Energy',
                    icon: Icons.grain_rounded,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMacroCard(
                    context: context,
                    label: 'Fats',
                    value: '${targets.targetFats.round()}g',
                    subtitle: 'Hormonal Support',
                    icon: Icons.water_drop_rounded,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Details Breakdown Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(
                    context: context,
                    label: 'Selected Goal',
                    value: _formatEnum(widget.goalType.name),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    context: context,
                    label: 'Experience Level',
                    value: _formatEnum(widget.fitnessLevel.name),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    context: context,
                    label: 'Activity Level',
                    value: _formatEnum(widget.activityLevel.name),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    context: context,
                    label: 'Current Weight ➔ Target',
                    value: '${widget.currentWeight.toStringAsFixed(1)} kg ➔ ${widget.targetWeight.toStringAsFixed(1)} kg',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            AppButton.primary(
              label: 'CREATE PLAN',
              onPressed: _onCreatePlanPressed,
              isPill: true,
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required BuildContext context,
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              color: context.appTextSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.headlineMd.copyWith(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTheme.bodySm.copyWith(
              color: context.appTextSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
        ),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 14,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  static String _formatEnum(String str) {
    if (str.isEmpty) return str;
    final camelCaseRegex = RegExp(r'(?<=[a-z])(?=[A-Z])');
    final words = str.split(camelCaseRegex);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
