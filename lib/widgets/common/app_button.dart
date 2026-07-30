import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum AppButtonVariant { primary, secondary, text, icon }

/// Unified Design System Button Component (`AppButton.primary`, `AppButton.secondary`, `AppButton.text`, `AppButton.icon`).
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final double? width;
  final bool isPill;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
    this.width,
    this.isPill = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
    this.width,
    this.isPill = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = 40,
    this.width,
    this.isPill = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.icon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.height = 40,
    this.width,
  }) : label = '',
       variant = AppButtonVariant.icon,
       isLoading = false,
       isFullWidth = false,
       isPill = false;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null && !widget.isLoading) {
      _scaleController.forward().then((_) => _scaleController.reverse());
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == AppButtonVariant.icon) {
      return IconButton(
        onPressed: widget.onPressed,
        icon: Container(
          width: widget.height,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.appOutlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(widget.icon, color: context.appTextPrimary, size: 20),
        ),
      );
    }

    if (widget.variant == AppButtonVariant.text) {
      return TextButton(
        onPressed: widget.isLoading ? null : _handleTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    final isPrimary = widget.variant == AppButtonVariant.primary;

    if (widget.isPill) {
      final backgroundColor = isPrimary
          ? context.appPrimary
          : context.appSurfaceElevated;
      final foregroundColor = isPrimary
          ? AppColors.onPrimary
          : context.appTextPrimary;

      return GestureDetector(
        onTapDown: widget.isLoading || widget.onPressed == null
            ? null
            : (_) => _scaleController.forward(),
        onTapUp: widget.isLoading || widget.onPressed == null
            ? null
            : (_) => _scaleController.reverse(),
        onTapCancel: widget.isLoading || widget.onPressed == null
            ? null
            : _scaleController.reverse,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
          child: Container(
            width:
                widget.width ?? (widget.isFullWidth ? double.infinity : null),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: widget.width != null || widget.isFullWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        foregroundColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: foregroundColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: AppTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final child = SizedBox(
      height: widget.height,
      width: widget.width ?? (widget.isFullWidth ? double.infinity : null),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : _handleTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isPrimary
                ? AppColors.primary
                : context.appSurfaceElevated,
            foregroundColor: isPrimary ? Colors.white : context.appTextPrimary,
            elevation: isPrimary ? 2 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: isPrimary
                  ? BorderSide.none
                  : BorderSide(
                      color: context.appOutlineVariant.withValues(alpha: 0.4),
                      width: 1,
                    ),
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? Colors.white : AppColors.primary,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 18,
                        color: isPrimary
                            ? Colors.white
                            : context.appTextPrimary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPrimary
                            ? Colors.white
                            : context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return child;
  }
}
