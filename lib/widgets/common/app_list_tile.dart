import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Design System List Tile component.
class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      final color = iconColor ?? AppColors.primary;
      leadingWidget = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDarkMode ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(leadingIcon, color: color, size: 18),
      );
    }

    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
      leading: leadingWidget,
      title: Text(
        title,
        style: AppTheme.bodySm.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.appTextPrimary,
        ),
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              subtitle!,
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
