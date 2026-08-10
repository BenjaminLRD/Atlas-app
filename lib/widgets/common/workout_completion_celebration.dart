import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/reward_queue_service.dart';
import 'app_animation.dart';
import 'app_button.dart';

/// Modal dialog celebrating completed workout sessions with animated stats and confetti.
class WorkoutCompletionCelebration extends StatelessWidget {
  final String workoutTitle;
  final int durationMinutes;
  final int exercisesCompleted;
  final int caloriesBurned;
  final int xpEarned;
  final bool isPersonalRecord;

  const WorkoutCompletionCelebration({
    super.key,
    required this.workoutTitle,
    required this.durationMinutes,
    required this.exercisesCompleted,
    required this.caloriesBurned,
    required this.xpEarned,
    this.isPersonalRecord = false,
  });

  /// Helper static launcher method
  static Future<void> show(
    BuildContext context, {
    required String workoutTitle,
    required int durationMinutes,
    required int exercisesCompleted,
    required int caloriesBurned,
    required int xpEarned,
    bool isPersonalRecord = false,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkoutCompletionCelebration(
        workoutTitle: workoutTitle,
        durationMinutes: durationMinutes,
        exercisesCompleted: exercisesCompleted,
        caloriesBurned: caloriesBurned,
        xpEarned: xpEarned,
        isPersonalRecord: isPersonalRecord,
      ),
    );

    if (context.mounted) {
      await RewardQueueService.instance.processQueue(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AppAnimation.confettiParticles(
      isAnimating: true,
      child: Center(
        child: AppAnimation.scaleIn(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14161D) : Colors.white,
                borderRadius: AppRadii.borderXl,
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header Trophy Icon with Glow
                  AppAnimation.pulseGlow(
                    color: AppColors.primaryContainer,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryContainer,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.primaryContainer,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Title & PR Banner
                  Text(
                    'WORKOUT COMPLETE!',
                    textAlign: TextAlign.center,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryContainer,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    workoutTitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (isPersonalRecord) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                        borderRadius: AppRadii.borderFull,
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFFD700)),
                          SizedBox(width: 4),
                          Text(
                            'NEW PERSONAL RECORD!',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // 3. Stats Grid Breakdown
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: AppRadii.borderLg,
                      border: Border.all(
                        color: context.appOutlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.timer_outlined,
                          label: 'TIME',
                          valueWidget: AppAnimation.countNumber(
                            endValue: durationMinutes,
                            suffix: 'm',
                            style: _statStyle(context),
                          ),
                        ),
                        _StatItem(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'EXERCISES',
                          valueWidget: AppAnimation.countNumber(
                            endValue: exercisesCompleted,
                            style: _statStyle(context),
                          ),
                        ),
                        _StatItem(
                          icon: Icons.local_fire_department_rounded,
                          label: 'CALORIES',
                          valueWidget: AppAnimation.countNumber(
                            endValue: caloriesBurned,
                            suffix: ' kcal',
                            style: _statStyle(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. XP Earned Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: AppRadii.borderMd,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.primaryContainer, size: 20),
                        const SizedBox(width: 4),
                        AppAnimation.countNumber(
                          endValue: xpEarned,
                          prefix: '+',
                          suffix: ' XP EARNED',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 5. Complete Button
                  AppButton.primary(
                    label: 'VIEW SUMMARY',
                    icon: Icons.done_all_rounded,
                    isPill: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _statStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: context.appTextPrimary,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget valueWidget;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryContainer),
        const SizedBox(height: 4),
        valueWidget,
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 9,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}
