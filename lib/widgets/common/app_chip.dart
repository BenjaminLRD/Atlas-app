import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum AppChipVariant {
  subtle,
  primary,
  status,
  selectable,
}

/// Reusable design system Chip / Badge widget.
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
  })  : icon = null,
        variant = AppChipVariant.selectable,
        color = null;

  const AppChip.primary({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  })  : variant = AppChipVariant.primary,
        isSelected = true,
        color = null;

  const AppChip.status({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
  })  : variant = AppChipVariant.status,
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
      duration: const Duration(milliseconds: 120),
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
        bgColor = isSelected ? AppColors.primary : context.appSurfaceElevated;
        textColor = isSelected ? Colors.white : context.appTextPrimary;
        border = isSelected
            ? null
            : Border.all(color: context.appOutlineVariant.withValues(alpha: 0.4), width: 1);
        break;
      case AppChipVariant.primary:
        bgColor = AppColors.primary;
        textColor = Colors.white;
        border = null;
        break;
      case AppChipVariant.status:
        bgColor = accentColor.withValues(alpha: context.isDarkMode ? 0.25 : 0.15);
        textColor = context.isDarkMode ? accentColor : accentColor;
        border = Border.all(color: accentColor.withValues(alpha: 0.3), width: 1);
        break;
      case AppChipVariant.subtle:
        bgColor = context.appSurfaceElevated;
        textColor = context.appTextSecondary;
        border = Border.all(color: context.appOutlineVariant.withValues(alpha: 0.3), width: 1);
        break;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap != null ? _handleTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
