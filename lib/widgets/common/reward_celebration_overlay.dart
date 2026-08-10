import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_button.dart';

/// Details configuration for universal reward celebration modal overlays.
class RewardCelebrationDetails {
  final String title;
  final String description;
  final int xpGained;
  final IconData icon;
  final Color? accentColor;
  final String buttonLabel;

  const RewardCelebrationDetails({
    required this.title,
    required this.description,
    required this.xpGained,
    this.icon = Icons.stars_rounded,
    this.accentColor,
    this.buttonLabel = 'CLAIM REWARD',
  });
}

/// Universal celebratory modal overlay presented when users earn post-workout XP bonuses,
/// complete challenges, or achieve milestones.
class RewardCelebrationOverlay extends StatelessWidget {
  final RewardCelebrationDetails details;

  const RewardCelebrationOverlay({
    super.key,
    required this.details,
  });

  /// Static launcher helper to present RewardCelebrationOverlay dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required int xpGained,
    IconData icon = Icons.stars_rounded,
    Color? accentColor,
    String buttonLabel = 'CLAIM REWARD',
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RewardCelebrationOverlay(
        details: RewardCelebrationDetails(
          title: title,
          description: description,
          xpGained: xpGained,
          icon: icon,
          accentColor: accentColor,
          buttonLabel: buttonLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = details.accentColor ?? AppColors.primaryContainer;

    return AppAnimation.confettiParticles(
      isAnimating: true,
      child: Center(
        child: AppAnimation.scaleIn(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181F) : Colors.white,
                borderRadius: AppRadii.borderXl,
                border: Border.all(
                  color: accent.withValues(alpha: isDark ? 0.4 : 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Icon Container with Pulse Glow
                  AppAnimation.pulseGlow(
                    color: accent,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        details.icon,
                        color: accent,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 2. Title
                  Text(
                    details.title,
                    textAlign: TextAlign.center,
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3. Description
                  Text(
                    details.description,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 4. XP Gained Animated Pill
                  if (details.xpGained > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: accent, size: 20),
                          const SizedBox(width: 6),
                          AppAnimation.countNumber(
                            endValue: details.xpGained,
                            prefix: '+',
                            suffix: ' XP BONUS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxl),

                  // 5. Action Button
                  AppButton.primary(
                    label: details.buttonLabel,
                    icon: Icons.emoji_events_rounded,
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
}
