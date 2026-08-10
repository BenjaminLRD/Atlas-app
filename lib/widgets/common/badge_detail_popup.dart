import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/badge.dart';
import 'app_button.dart';

/// Reusable modal popup to view detailed achievement badge information.
class BadgeDetailPopup extends StatefulWidget {
  final AchievementBadge badge;

  const BadgeDetailPopup({
    super.key,
    required this.badge,
  });

  /// Helper static method to trigger dialog modal
  static Future<void> show(BuildContext context, AchievementBadge badge) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BadgeDetailPopup(badge: badge),
    );
  }

  @override
  State<BadgeDetailPopup> createState() => _BadgeDetailPopupState();
}

class _BadgeDetailPopupState extends State<BadgeDetailPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

  String _formatEarnedDate(DateTime? date) {
    if (date == null) return 'Not Yet Earned';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[date.month - 1];
    final day = date.day;
    final year = date.year;

    final hourNum = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minStr = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';

    return '$monthStr $day, $year • $hourNum:$minStr $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final rarityColor = _getRarityColor(widget.badge.rarity);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14151B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: rarityColor.withValues(alpha: isDark ? 0.4 : 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Category & Rarity Tags Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          widget.badge.rarity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: rarityColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.badge.category,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Large Badge Icon Emblem with Glow
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.6)
                          : const Color(0xFFFFF9E6),
                      border: Border.all(
                        color: rarityColor,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rarityColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.badge.iconData,
                      size: 48,
                      color: rarityColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Badge Title
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

                  // 4. Description Text
                  Text(
                    widget.badge.description,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 13,
                      color: context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Earned Date Timestamp Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.appOutlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'EARNED ON',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: context.appTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatEarnedDate(widget.badge.earnedDate),
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: rarityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Action Button
                  AppButton.primary(
                    label: 'CLOSE',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context),
                    isPill: true,
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
