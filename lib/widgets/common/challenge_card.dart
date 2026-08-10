import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/weekly_challenge.dart';
import 'app_button.dart';

/// Reusable Challenge Card widget displaying live weekly challenge progress,
/// XP reward badge, completion state, and interactive detail modal.
class ChallengeCard extends StatelessWidget {
  final WeeklyChallenge challenge;
  final VoidCallback? onTap;
  final double width;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
    this.width = 280.0,
  });

  /// Helper to present challenge detail popup modal
  static Future<void> showDetailModal(BuildContext context, WeeklyChallenge challenge) async {
    final isDark = context.isDarkMode;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1C22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: challenge.completed
                  ? AppColors.primary
                  : AppColors.primaryContainer.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (challenge.completed ? AppColors.primary : AppColors.primaryContainer)
                    .withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      challenge.category.toUpperCase(),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                  if (challenge.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                challenge.title,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                challenge.description,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Progress Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    challenge.formattedProgress,
                    style: AppTheme.headlineLgMobile.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: challenge.completed
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: challenge.progressPercentage,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    challenge.completed ? AppColors.primary : AppColors.primaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // XP Reward Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primaryContainer, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REWARD',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            color: context.appTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '+${challenge.xpReward} XP',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton.secondary(
                label: 'CLOSE',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bool isCompleted = challenge.completed;

    return GestureDetector(
      onTap: onTap ?? () => showDetailModal(context, challenge),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14151B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.primaryContainer.withValues(alpha: 0.35),
            width: isCompleted ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? AppColors.primary : AppColors.primaryContainer)
                  .withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Category tag + Completed or XP Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    challenge.category.toUpperCase(),
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryContainer,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                        SizedBox(width: 2),
                        Text(
                          'DONE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: AppColors.primaryContainer),
                        const SizedBox(width: 2),
                        Text(
                          '+${challenge.xpReward} XP',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Description
            Text(
              challenge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headlineLgMobile.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              challenge.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Numerical Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
                Text(
                  challenge.formattedProgress,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.primary : context.appTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: challenge.progressPercentage,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.primary : AppColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
