import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import 'app_image.dart';

enum AppHeaderVariant { standard, back, centered }

/// Standardized, reusable top header widget used across the entire application.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final AppHeaderVariant variant;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String userInitials;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBackTap;
  final VoidCallback? onMenuTap;
  final Widget? trailing;
  final Widget? leading;
  final bool showNotifications;
  final bool showSettings;
  final bool showMenuButton;
  final bool showAvatar;
  final bool useSafeArea;

  const AppHeader.standard({
    super.key,
    this.title = 'Atlas',
    this.subtitle = 'Your fitness journey',
    this.avatarUrl,
    this.userInitials = 'AG',
    this.onAvatarTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.onMenuTap,
    this.leading,
    this.showNotifications = false,
    this.showSettings = true,
    this.showMenuButton = true,
    this.showAvatar = false,
    this.useSafeArea = true,
  }) : variant = AppHeaderVariant.standard,
       onBackTap = null,
       trailing = null;

  const AppHeader.back({
    super.key,
    required this.title,
    this.subtitle,
    this.onBackTap,
    this.trailing,
    this.useSafeArea = true,
  }) : variant = AppHeaderVariant.back,
       avatarUrl = null,
       userInitials = 'AG',
       onAvatarTap = null,
       onNotificationsTap = null,
       onSettingsTap = null,
       onMenuTap = null,
       leading = null,
       showNotifications = false,
       showSettings = false,
       showMenuButton = false,
       showAvatar = false;

  const AppHeader.centered({
    super.key,
    required this.title,
    this.onBackTap,
    this.trailing,
    this.useSafeArea = true,
  }) : variant = AppHeaderVariant.centered,
       subtitle = null,
       avatarUrl = null,
       userInitials = 'AG',
       onAvatarTap = null,
       onNotificationsTap = null,
       onSettingsTap = null,
       onMenuTap = null,
       leading = null,
       showNotifications = false,
       showSettings = false,
       showMenuButton = false,
       showAvatar = false;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 360;
    final horizontalPadding = isSmallScreen ? AppSpacing.md : AppSpacing.lg;

    final headerContent = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppSpacing.sm,
      ),
      color: Colors.transparent,
      child: switch (variant) {
        AppHeaderVariant.standard => _buildStandardHeader(context),
        AppHeaderVariant.back => _buildBackHeader(context),
        AppHeaderVariant.centered => _buildCenteredHeader(context),
      },
    );

    if (useSafeArea) {
      return SafeArea(bottom: false, child: headerContent);
    }
    return headerContent;
  }

  Widget _buildStandardHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gap = screenWidth <= 360 ? 8.0 : 12.0;

    Widget leadingWidget;
    if (leading != null) {
      leadingWidget = leading!;
    } else if (showMenuButton) {
      leadingWidget = SizedBox(
        width: 44,
        height: 44,
        child: Semantics(
          button: true,
          label: 'Open navigation menu',
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (onMenuTap != null) {
                onMenuTap!();
              } else {
                _openDrawer(context);
              }
            },
            tooltip: 'Open navigation menu',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.appOutlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.25 : 0.06,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_rounded,
                color: context.appTextPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      );
    } else if (showAvatar || onAvatarTap != null) {
      leadingWidget = _buildAvatarWidget(context);
    } else {
      leadingWidget = const SizedBox.shrink();
    }

    return Row(
      children: [
        leadingWidget,
        SizedBox(width: gap),

        // Title & Subtitle Column (Flexible width, single line ellipsis, no overflow)
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: gap),

        // Right Notification, Settings, and Avatar Actions (Fixed width, non-overlapping)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showNotifications)
              _buildHeaderActionButton(
                context: context,
                icon: Icons.notifications_outlined,
                badge: true,
                onPressed: onNotificationsTap,
              ),
            if (showNotifications &&
                (showSettings ||
                    (showMenuButton && (showAvatar || onAvatarTap != null))))
              SizedBox(width: gap),
            if (showSettings)
              _buildHeaderActionButton(
                context: context,
                icon: Icons.settings_outlined,
                onPressed: onSettingsTap,
              ),
            if (showSettings &&
                (showMenuButton && (showAvatar || onAvatarTap != null)))
              SizedBox(width: gap),
            if (showMenuButton && (showAvatar || onAvatarTap != null))
              _buildAvatarWidget(context),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarWidget(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        label: 'User profile avatar',
        enabled: onAvatarTap != null,
        child: Tooltip(
          message: 'View Profile',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: AppImage.avatar(
                  imageUrl: avatarUrl,
                  radius: 20,
                  name: userInitials,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gap = screenWidth <= 360 ? 8.0 : 12.0;

    return Row(
      children: [
        _buildHeaderActionButton(
          context: context,
          icon: Icons.chevron_left_rounded,
          iconSize: 24,
          onPressed: onBackTap,
        ),
        SizedBox(width: gap),

        Expanded(
          // The toolbar has a fixed height, so its two text lines scale only
          // up to 1.3x; the rest of the screen follows the system setting.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headlineLg.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (trailing != null) ...[
          SizedBox(width: gap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88, maxHeight: 44),
            child: trailing!,
          ),
        ],
      ],
    );
  }

  Widget _buildCenteredHeader(BuildContext context) {
    return Row(
      children: [
        _buildHeaderActionButton(
          context: context,
          icon: Icons.chevron_left_rounded,
          iconSize: 24,
          onPressed: onBackTap,
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headlineLg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: Center(child: trailing ?? const SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required BuildContext context,
    required IconData icon,
    VoidCallback? onPressed,
    double iconSize = 20,
    bool badge = false,
    String? tooltip,
  }) {
    final defaultTooltip = icon == Icons.chevron_left_rounded
        ? 'Back'
        : (icon == Icons.notifications_outlined
              ? 'Notifications'
              : (icon == Icons.settings_outlined ? 'Settings' : 'Action'));
    final effectiveTooltip = tooltip ?? defaultTooltip;

    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        tooltip: effectiveTooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.appOutlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.2 : 0.05,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: context.appTextPrimary, size: iconSize),
            ),
            if (badge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _openDrawer(BuildContext context) {
    final nearest = Scaffold.maybeOf(context);
    if (nearest != null && nearest.hasDrawer) {
      nearest.openDrawer();
      return;
    }

    ScaffoldState? target;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScaffoldState) {
        final state = element.state as ScaffoldState;
        if (state.hasDrawer) {
          target = state;
          return false;
        }
      }
      return true;
    });
    target?.openDrawer();
  }
}
