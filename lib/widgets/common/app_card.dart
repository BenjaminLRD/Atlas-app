import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Card Component matching the Atlas Vitality Design System.
/// Features a solid #FFFFFF surface with 20px radius (`AppRadii.xl`),
/// a subtle #D7EEDB green border, and soft elevation shadow (`AppShadows.softCard`).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableBlur;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadii.xl,
    this.backgroundColor,
    this.borderColor,
    this.enableBlur = false,
    this.onTap,
    this.boxShadow,
    this.clipBehavior = Clip.none,
  });

  const AppCard.flat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadii.xl,
    this.backgroundColor,
    this.borderColor,
    this.enableBlur = false,
    this.onTap,
    this.clipBehavior = Clip.none,
  }) : boxShadow = const [];

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? context.appCardBg;
    final effectiveBorder = borderColor ?? context.appCardBorder;
    final effectiveShadow = boxShadow ?? [context.appCardShadow];

    Widget content = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (enableBlur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      return Semantics(
        button: true,
        enabled: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content;
  }
}
