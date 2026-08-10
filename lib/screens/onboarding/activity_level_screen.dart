import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/user_goal.dart';
import '../../widgets/common/app_card.dart';

class ActivityLevelScreen extends StatelessWidget {
  final ActivityLevel selectedActivity;
  final ValueChanged<ActivityLevel> onActivitySelected;

  const ActivityLevelScreen({
    super.key,
    required this.selectedActivity,
    required this.onActivitySelected,
  });

  static const List<_ActivityOptionItem> _options = [
    _ActivityOptionItem(
      activity: ActivityLevel.sedentary,
      title: 'Sedentary',
      subtitle: 'Little or no regular physical exercise (desk job, minimal movement)',
      icon: Icons.chair_rounded,
    ),
    _ActivityOptionItem(
      activity: ActivityLevel.light,
      title: 'Light Activity',
      subtitle: 'Light exercise or light sports 1 – 3 days per week',
      icon: Icons.directions_walk_rounded,
    ),
    _ActivityOptionItem(
      activity: ActivityLevel.moderate,
      title: 'Moderate Activity',
      subtitle: 'Moderate exercise or structured training 3 – 5 days per week',
      icon: Icons.fitness_center_rounded,
    ),
    _ActivityOptionItem(
      activity: ActivityLevel.active,
      title: 'Very Active',
      subtitle: 'Hard exercise, heavy lifting, or sports 6 – 7 days per week',
      icon: Icons.directions_run_rounded,
    ),
    _ActivityOptionItem(
      activity: ActivityLevel.veryActive,
      title: 'Athlete / Physical Work',
      subtitle: 'Very hard daily exercise, physical job, or double training sessions',
      icon: Icons.bolt_rounded,
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
            'What is your daily activity level?',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Determines your Total Daily Energy Expenditure (TDEE) multiplier.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),
          ..._options.map((opt) {
            final isSelected = selectedActivity == opt.activity;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () => onActivitySelected(opt.activity),
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
                      child: Icon(
                        opt.icon,
                        color: isSelected
                            ? AppColors.onPrimary
                            : context.appTextSecondary,
                        size: 22,
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

class _ActivityOptionItem {
  final ActivityLevel activity;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ActivityOptionItem({
    required this.activity,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
