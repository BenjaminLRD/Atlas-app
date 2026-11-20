import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// High-performance, premium Glassmorphism container for key floating elements:
/// - Floating AI Coach button
/// - Chat bubbles
/// - Floating Bottom Navigation
/// - Custom Navigation Drawer
class AppGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  const AppGlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.color,
    this.gradient,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Factory preset for floating action buttons (like AI Coach button).
  factory AppGlassContainer.fab({
    Key? key,
    required Widget child,
    required BuildContext context,
    double blur = 14.0,
    double size = 52.0,
    bool isHovered = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppGlassContainer(
      key: key,
      width: size,
      height: size,
      blur: blur,
      borderRadius: BorderRadius.circular(size / 2),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF165B22).withValues(alpha: 0.85),
                const Color(0xFF0F3818).withValues(alpha: 0.75),
              ]
            : [
                const Color(0xFF16A34A).withValues(alpha: 0.88),
                AppColors.primary.withValues(alpha: 0.82),
              ],
      ),
      border: Border.all(
        color: isDark
            ? AppColors.primaryContainer.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.5),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? AppColors.primaryContainer.withValues(
                  alpha: isHovered ? 0.6 : 0.4,
                )
              : AppColors.primary.withValues(alpha: isHovered ? 0.45 : 0.3),
          blurRadius: isHovered ? 20.0 : 14.0,
          spreadRadius: isHovered ? 2.0 : 0.5,
          offset: const Offset(0, 4),
        ),
      ],
      child: Center(child: child),
    );
  }

  /// Factory preset for floating Bottom Navigation Bar.
  factory AppGlassContainer.bottomNav({
    Key? key,
    required Widget child,
    required BuildContext context,
    double blur = 20.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppGlassContainer(
      key: key,
      blur: blur,
      borderRadius: BorderRadius.circular(28),
      color: isDark
          ? const Color(0xFF131619).withValues(alpha: 0.88)
          : const Color(0xFFF7FAF7).withValues(alpha: 0.90),
      border: Border.all(
        color: isDark
            ? const Color(0xFF28342C).withValues(alpha: 0.8)
            : const Color(0xFFD7EEDB).withValues(alpha: 0.85),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: child,
    );
  }

  /// Factory preset for Chat Bubble (AI Coach & User).
  factory AppGlassContainer.chatBubble({
    Key? key,
    required Widget child,
    required BuildContext context,
    required bool isUser,
    double blur = 12.0,
    BorderRadius? customBorderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    if (isUser) {
      return AppGlassContainer(
        key: key,
        blur: blur,
        borderRadius: customBorderRadius ?? defaultRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryContainer.withValues(alpha: 0.88),
                  const Color(0xFF1E8238).withValues(alpha: 0.82),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.92),
                  const Color(0xFF077430).withValues(alpha: 0.86),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        padding: const EdgeInsets.all(16),
        child: child,
      );
    } else {
      return AppGlassContainer(
        key: key,
        blur: blur,
        borderRadius: customBorderRadius ?? defaultRadius,
        color: isDark
            ? const Color(0xFF1A1E24).withValues(alpha: 0.80)
            : Colors.white.withValues(alpha: 0.86),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.cardBorder.withValues(alpha: 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
        padding: const EdgeInsets.all(16),
        child: child,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    final radius = borderRadius is BorderRadius
        ? borderRadius as BorderRadius
        : BorderRadius.zero;

    return Container(
      width: width,
      height: height,
      margin: margin,
      constraints: constraints,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              gradient: gradient,
              borderRadius: borderRadius,
              border: border,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
