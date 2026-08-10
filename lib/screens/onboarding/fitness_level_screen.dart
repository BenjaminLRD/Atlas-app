import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/user_goal.dart';
import '../../widgets/common/app_card.dart';

class FitnessLevelScreen extends StatelessWidget {
  final FitnessLevel selectedLevel;
  final ValueChanged<FitnessLevel> onLevelSelected;

  const FitnessLevelScreen({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  static const List<_LevelOptionItem> _options = [
    _LevelOptionItem(
      level: FitnessLevel.beginner,
      title: 'Beginner',
      subtitle: 'New to structured lifting or returning after a long break (< 6 months)',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    _LevelOptionItem(
      level: FitnessLevel.intermediate,
      title: 'Intermediate',
      subtitle: 'Consistent weight training experience (1 – 3 years of lifting)',
      icon: Icons.trending_up_rounded,
    ),
    _LevelOptionItem(
      level: FitnessLevel.advanced,
      title: 'Advanced',
      subtitle: 'Experienced lifter with established strength base & technique (3+ years)',
      icon: Icons.workspace_premium_rounded,
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
            'What is your fitness level?',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Helps us calibrate workout volume and progressive overload recommendations.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),
          ..._options.map((opt) {
            final isSelected = selectedLevel == opt.level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                onTap: () => onLevelSelected(opt.level),
                padding: const EdgeInsets.all(18),
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
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 17,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.subtitle,
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 13,
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

class _LevelOptionItem {
  final FitnessLevel level;
  final String title;
  final String subtitle;
  final IconData icon;

  const _LevelOptionItem({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
