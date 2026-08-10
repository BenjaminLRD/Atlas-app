import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_button.dart';

/// Details payload passed when a user ranks up after completing a workout.
class RankUpDetails {
  final String previousRank;
  final String newRank;
  final int xpGained;
  final String message;

  const RankUpDetails({
    required this.previousRank,
    required this.newRank,
    required this.xpGained,
    required this.message,
  });
}

/// Premium celebration modal shown when a user advances to a new competitive rank.
class RankUpDialog extends StatefulWidget {
  final RankUpDetails details;

  const RankUpDialog({
    super.key,
    required this.details,
  });

  /// Helper launcher to present RankUpDialog modal
  static Future<void> show(BuildContext context, RankUpDetails details) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RankUpDialog(details: details),
    );
  }

  @override
  State<RankUpDialog> createState() => _RankUpDialogState();
}

class _RankUpDialogState extends State<RankUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AppAnimation.confettiParticles(
      isAnimating: true,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14151B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.4 : 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.2 : 0.15),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.15 : 0.1),
                      blurRadius: 48,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Top Celebration Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        '🎉 RANK UP!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD700),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Animated Rank Emblem Badge
                    AppAnimation.pulseGlow(
                      color: const Color(0xFFFFD700),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFFFFF9E6),
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.military_tech_rounded,
                          size: 58,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. New Rank Title
                    Text(
                      widget.details.newRank,
                      style: AppTheme.headlineLgMobile.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 4. Progression Banner (Previous Rank -> New Rank)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.details.previousRank,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.details.newRank,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 5. XP Reward Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                            color: AppColors.primaryContainer,
                          ),
                          const SizedBox(width: 6),
                          AppAnimation.countNumber(
                            endValue: widget.details.xpGained,
                            prefix: '+',
                            suffix: ' XP GAINED',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryContainer,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 6. Motivational Message
                  Text(
                    widget.details.message,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 7. Claim Rank / Continue Button
                  AppButton.primary(
                    label: 'CLAIM RANK',
                    icon: Icons.emoji_events_rounded,
                    onPressed: () => Navigator.pop(context),
                    isPill: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
