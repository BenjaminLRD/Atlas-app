import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum AppButtonVariant { primary, secondary, outlined, text, icon }

/// Unified Design System Button Component.
/// - `AppButton.primary`: Green filled (#0A8F3C) for high-emphasis actions (e.g. "Start Workout", "View Plan", "Save").
/// - `AppButton.secondary`: Soft green (#CFF5D7) for medium-emphasis secondary actions (e.g. "Cancel", "Learn More").
/// - `AppButton.outlined`: Outlined with subtle border for secondary options.
/// - `AppButton.text`: Text-only ghost button.
/// - `AppButton.icon`: Circular icon button.
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
  final double borderRadius;

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
    this.borderRadius = 14.0,
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
    this.borderRadius = 14.0,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
    this.width,
    this.isPill = false,
    this.borderRadius = 14.0,
  }) : variant = AppButtonVariant.outlined;

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
    this.borderRadius = 14.0,
  }) : variant = AppButtonVariant.text;

  const AppButton.icon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.height = 40,
    this.width,
    this.label = '',
  }) : variant = AppButtonVariant.icon,
       isLoading = false,
       isFullWidth = false,
       isPill = false,
       borderRadius = 999.0;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _scaleController.stop();
    } catch (_) {}
    _scaleController.dispose();
    super.dispose();
  }

  void _safeForward() {
    if (mounted && !_isDisposed) {
      try {
        _scaleController.forward();
      } catch (_) {}
    }
  }

  void _safeReverse() {
    if (mounted && !_isDisposed) {
      try {
        _scaleController.reverse();
      } catch (_) {}
    }
  }

  Future<void> _handleTap() async {
    if (widget.onPressed != null && !widget.isLoading) {
      if (mounted && !_isDisposed) {
        try {
          await _scaleController.forward().orCancel;
          if (mounted && !_isDisposed) {
            await _scaleController.reverse().orCancel;
          }
        } catch (_) {}
      }
      if (mounted && widget.onPressed != null) {
        widget.onPressed!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == AppButtonVariant.icon) {
      return Semantics(
        button: true,
        enabled: widget.onPressed != null,
        label: widget.label.isNotEmpty ? widget.label : 'Icon action',
        child: IconButton(
          onPressed: widget.onPressed,
          icon: Container(
            width: widget.height,
            height: widget.height,
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: context.appCardBorder, width: 1),
              boxShadow: [context.appCardShadow],
            ),
            child: Icon(widget.icon, color: context.appTextPrimary, size: 20),
          ),
        ),
      );
    }

    if (widget.variant == AppButtonVariant.text) {
      return Semantics(
        button: true,
        enabled: widget.onPressed != null && !widget.isLoading,
        label: widget.label,
        child: TextButton(
          onPressed: widget.isLoading ? null : _handleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: context.appPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPrimary = widget.variant == AppButtonVariant.primary;
    final isSecondary = widget.variant == AppButtonVariant.secondary;
    final isOutlined = widget.variant == AppButtonVariant.outlined;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;
    List<BoxShadow> boxShadow = [];

    if (isPrimary) {
      backgroundColor = AppColors.primary;
      foregroundColor = AppColors.onPrimary;
      border = null;
      boxShadow = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isSecondary) {
      backgroundColor = context.isDarkMode
          ? AppColors.primary.withValues(alpha: 0.2)
          : AppColors.secondary;
      foregroundColor = context.isDarkMode
          ? AppColors.darkPrimary
          : AppColors.primary;
      border = Border.all(
        color: context.isDarkMode
            ? AppColors.darkPrimary.withValues(alpha: 0.3)
            : AppColors.cardBorder,
        width: 1,
      );
    } else if (isOutlined) {
      backgroundColor = Colors.transparent;
      foregroundColor = context.isDarkMode
          ? AppColors.darkPrimary
          : AppColors.primary;
      border = Border.all(color: context.appCardBorder, width: 1.5);
    } else {
      backgroundColor = context.appSurfaceElevated;
      foregroundColor = context.appTextPrimary;
      border = Border.all(color: context.appCardBorder, width: 1);
    }

    final effectiveRadius = widget.isPill ? 999.0 : widget.borderRadius;

    if (widget.isPill) {
      return Semantics(
        button: true,
        label: widget.label,
        enabled: widget.onPressed != null && !widget.isLoading,
        child: GestureDetector(
          onTapDown: widget.isLoading || widget.onPressed == null
              ? null
              : (_) => _safeForward(),
          onTapUp: widget.isLoading || widget.onPressed == null
              ? null
              : (_) => _safeReverse(),
          onTapCancel: widget.isLoading || widget.onPressed == null
              ? null
              : () => _safeReverse(),
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
                border: border,
                boxShadow: boxShadow,
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: foregroundColor,
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

    final child = SizedBox(
      height: widget.height,
      width: widget.width ?? (widget.isFullWidth ? double.infinity : null),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(effectiveRadius),
            boxShadow: boxShadow,
          ),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _handleTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size(widget.width ?? 44, widget.height),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                side: border?.top ?? BorderSide.none,
              ),
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        foregroundColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: foregroundColor),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodyMd.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: foregroundColor,
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

    return Semantics(
      button: true,
      enabled: widget.onPressed != null && !widget.isLoading,
      label: widget.label,
      child: child,
    );
  }
}
