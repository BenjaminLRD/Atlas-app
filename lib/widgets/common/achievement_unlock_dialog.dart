import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/badge.dart';
import 'app_animation.dart';
import 'app_button.dart';

/// Modal dialog celebrating newly unlocked fitness achievements.
class AchievementUnlockDialog extends StatefulWidget {
  final AchievementBadge badge;

  const AchievementUnlockDialog({
    super.key,
    required this.badge,
  });

  /// Helper static method to trigger dialog modal
  static Future<void> show(BuildContext context, AchievementBadge badge) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AchievementUnlockDialog(badge: badge),
    );
  }

  @override
  State<AchievementUnlockDialog> createState() => _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
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

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFFD700); // Gold
      case 'epic':
        return const Color(0xFFFF6D00); // Glowing Orange
      case 'rare':
        return const Color(0xFF00E5FF); // Electric Cyan
      case 'common':
      default:
        return AppColors.primaryContainer; // Vitality Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final rarityColor = _getRarityColor(widget.badge.rarity);

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
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14151B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: isDark ? 0.5 : 0.7),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Header Title
                    Text(
                      '🏆 ACHIEVEMENT UNLOCKED',
                      textAlign: TextAlign.center,
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: rarityColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Glowing Badge Icon Emblem
                    AppAnimation.pulseGlow(
                      color: rarityColor,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFFE8F5E9),
                          border: Border.all(
                            color: rarityColor,
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.badge.iconData,
                          size: 52,
                          color: rarityColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 3. Rarity & Category Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${widget.badge.rarity.toUpperCase()} • ${widget.badge.category.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: rarityColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Achievement Name
                  Text(
                    widget.badge.title,
                    textAlign: TextAlign.center,
                    style: AppTheme.headlineLgMobile.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 5. Description / Quote
                  Text(
                    widget.badge.description,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 13,
                      color: context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. Continue Button
                  AppButton.primary(
                    label: 'CONTINUE',
                    icon: Icons.arrow_forward_rounded,
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
