import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/daily_brief.dart';
import '../../providers/fitness_provider.dart';
import '../../screens/daily_brief_screen.dart';
import '../common/app_card.dart';

/// Dashboard summary widget displaying the proactive AI Coach Daily Brief.
class DailyBriefCard extends StatelessWidget {
  final DailyBrief? brief;
  final VoidCallback? onTap;

  const DailyBriefCard({
    super.key,
    this.brief,
    this.onTap,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBrief = brief ?? FitnessProvider.instance.dailyBrief;

    if (activeBrief == null) {
      return const SizedBox.shrink();
    }

    final greeting = _getTimeGreeting();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderLg,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
          gradient: LinearGradient(
            colors: [
              AppColors.primaryContainer.withValues(alpha: context.isDarkMode ? 0.25 : 0.1),
              context.appCardBg,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Greeting & Avatar
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              greeting,
                              style: AppTheme.labelCaps.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: AppRadii.borderFull,
                              ),
                              child: Text(
                                'DAILY BRIEF',
                                style: AppTheme.labelCaps.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeBrief.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyLg.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Brief Summary Text
              Text(
                activeBrief.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMd.copyWith(
                  color: context.appTextSecondary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Focus Area & Insight Chips
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: AppRadii.borderFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.center_focus_strong,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activeBrief.focusArea,
                          style: AppTheme.labelCaps.copyWith(
                            color: context.appTextPrimary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...activeBrief.items.take(2).map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: AppRadii.borderFull,
                      ),
                      child: Text(
                        item.title,
                        style: AppTheme.labelCaps.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Button Row
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (onTap != null) {
                      onTap!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyBriefScreen(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderMd,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.read_more_rounded, size: 18),
                  label: Text(
                    'VIEW DAILY BRIEF',
                    style: AppTheme.labelCaps.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
