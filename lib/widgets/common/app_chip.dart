import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum AppChipVariant { subtle, primary, status, selectable }

/// Reusable design system Chip / Filter Badge widget.
/// - Active State: Soft green-tinted background (#CFF5D7) with #0A8F3C green text and subtle border.
/// - Inactive State: Light grey-green background (#E8F0EA) with #4B5563 text and subtle #D7EEDB border.
class AppChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final AppChipVariant variant;
  final bool isSelected;
  final Color? color;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppChipVariant.subtle,
    this.isSelected = false,
    this.color,
    this.onTap,
  });

  const AppChip.selectable({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : icon = null,
       variant = AppChipVariant.selectable,
       color = null;

  const AppChip.primary({super.key, required this.label, this.icon, this.onTap})
    : variant = AppChipVariant.primary,
      isSelected = true,
      color = null;

  const AppChip.status({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
  }) : variant = AppChipVariant.status,
       isSelected = false;

  @override
  State<AppChip> createState() => _AppChipState();
}

class _AppChipState extends State<AppChip> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final accentColor = widget.color ?? AppColors.primary;

    Color bgColor;
    Color textColor;
    Border? border;

    switch (widget.variant) {
      case AppChipVariant.selectable:
        if (isSelected) {
          bgColor = context.isDarkMode
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.secondary;
          textColor = context.isDarkMode
              ? AppColors.darkPrimary
              : AppColors.primary;
          border = Border.all(
            color: context.isDarkMode
                ? AppColors.darkPrimary.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.35),
            width: 1,
          );
        } else {
          bgColor = context.isDarkMode
              ? const Color(0xFF1B1E20)
              : AppColors.surfaceContainerLow;
          textColor = context.isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          border = Border.all(color: context.appCardBorder, width: 1);
        }
        break;

      case AppChipVariant.primary:
        bgColor = context.isDarkMode
            ? AppColors.primary.withValues(alpha: 0.25)
            : AppColors.secondary;
        textColor = context.isDarkMode
            ? AppColors.darkPrimary
            : AppColors.primary;
        border = Border.all(
          color: context.isDarkMode
              ? AppColors.darkPrimary.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        );
        break;

      case AppChipVariant.status:
        bgColor = accentColor.withValues(
          alpha: context.isDarkMode ? 0.25 : 0.15,
        );
        textColor = accentColor;
        border = Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        );
        break;

      case AppChipVariant.subtle:
        bgColor = context.isDarkMode
            ? const Color(0xFF1B1E20)
            : AppColors.surfaceContainerLow;
        textColor = context.isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        border = Border.all(color: context.appCardBorder, width: 1);
        break;
    }

    return Semantics(
      button: widget.onTap != null,
      selected: widget.variant == AppChipVariant.selectable ? isSelected : null,
      label: widget.label,
      enabled: widget.onTap != null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: GestureDetector(
          onTap: widget.onTap != null ? _handleTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            constraints: BoxConstraints(
              minHeight: widget.onTap != null ? 44.0 : 32.0,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadii.borderFull,
              border: border,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 13, color: textColor),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
