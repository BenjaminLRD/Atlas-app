import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/user_goal.dart';
import '../../widgets/common/app_card.dart';

class GoalSelectionScreen extends StatelessWidget {
  final FitnessGoalType selectedGoal;
  final ValueChanged<FitnessGoalType> onGoalSelected;

  const GoalSelectionScreen({
    super.key,
    required this.selectedGoal,
    required this.onGoalSelected,
  });

  static const List<_GoalOptionItem> _options = [
    _GoalOptionItem(
      type: FitnessGoalType.muscleGain,
      title: 'Muscle Gain',
      subtitle: 'Build lean muscle mass & increase strength',
      emoji: '💪',
      icon: Icons.fitness_center_rounded,
    ),
    _GoalOptionItem(
      type: FitnessGoalType.fatLoss,
      title: 'Fat Loss',
      subtitle: 'Burn body fat while preserving lean muscle',
      emoji: '🔥',
      icon: Icons.local_fire_department_rounded,
    ),
    _GoalOptionItem(
      type: FitnessGoalType.maintenance,
      title: 'Maintenance',
      subtitle: 'Maintain current weight & optimize overall fitness',
      emoji: '⚖️',
      icon: Icons.balance_rounded,
    ),
    _GoalOptionItem(
      type: FitnessGoalType.strength,
      title: 'Strength',
      subtitle: 'Maximize heavy compound lifting performance',
      emoji: '🏋',
      icon: Icons.bolt_rounded,
    ),
    _GoalOptionItem(
      type: FitnessGoalType.endurance,
      title: 'Endurance',
      subtitle: 'Improve stamina, energy & cardiovascular health',
      emoji: '🏃',
      icon: Icons.directions_run_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is your primary goal?',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your target to personalize your caloric and macro targets.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),
          ..._options.map((opt) {
            final isSelected = selectedGoal == opt.type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () => onGoalSelected(opt.type),
                padding: const EdgeInsets.all(16),
                borderColor: isSelected
                    ? AppColors.primaryContainer
                    : context.appOutlineVariant.withValues(alpha: 0.3),
                backgroundColor: isSelected
                    ? AppColors.secondaryContainer.withValues(alpha: 0.25)
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.appPrimary
                            : context.appSurfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        opt.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 16,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            opt.subtitle,
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : context.appTextSecondary.withValues(alpha: 0.4),
                      size: 22,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GoalOptionItem {
  final FitnessGoalType type;
  final String title;
  final String subtitle;
  final String emoji;
  final IconData icon;

  const _GoalOptionItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.icon,
  });
}
