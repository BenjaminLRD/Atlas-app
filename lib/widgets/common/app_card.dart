import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableBlur;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadii.xl,
    this.backgroundColor,
    this.borderColor,
    this.enableBlur = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? context.appCardBg;
    final effectiveBorder = borderColor ?? context.appCardBorder;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: [
          context.appCardShadow,
        ],
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
          child: content,
        ),
      );
    }

    return content;
  }
}
