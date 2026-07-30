import 'package:flutter/material.dart';
import '../../app_theme.dart';

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
  final Widget? trailing;
  final bool showNotifications;
  final bool showSettings;

  const AppHeader.standard({
    super.key,
    this.title = 'Aizawl Gym',
    this.subtitle = 'Your fitness journey',
    this.avatarUrl,
    this.userInitials = 'AG',
    this.onAvatarTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.showNotifications = true,
    this.showSettings = true,
  }) : variant = AppHeaderVariant.standard,
       onBackTap = null,
       trailing = null;

  const AppHeader.back({
    super.key,
    required this.title,
    this.subtitle,
    this.onBackTap,
    this.trailing,
  }) : variant = AppHeaderVariant.back,
       avatarUrl = null,
       userInitials = 'AG',
       onAvatarTap = null,
       onNotificationsTap = null,
       onSettingsTap = null,
       showNotifications = false,
       showSettings = false;

  const AppHeader.centered({
    super.key,
    required this.title,
    this.onBackTap,
    this.trailing,
  }) : variant = AppHeaderVariant.centered,
       subtitle = null,
       avatarUrl = null,
       userInitials = 'AG',
       onAvatarTap = null,
       onNotificationsTap = null,
       onSettingsTap = null,
       showNotifications = false,
       showSettings = false;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.transparent,
        child: switch (variant) {
          AppHeaderVariant.standard => _buildStandardHeader(context),
          AppHeaderVariant.back => _buildBackHeader(context),
          AppHeaderVariant.centered => _buildCenteredHeader(context),
        },
      ),
    );
  }

  Widget _buildStandardHeader(BuildContext context) {
    return Row(
      children: [
        // Left Avatar Circle
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              border: Border.all(color: AppColors.primary, width: 1.5),
              image: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    userInitials,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),

        // Title & Subtitle Stack
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.headlineLg.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 1),
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
        const SizedBox(width: 12),

        // Right Notification & Settings Buttons (Aligned with 16px Spacing)
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
            if (showNotifications && showSettings) const SizedBox(width: 16),
            if (showSettings)
              _buildHeaderActionButton(
                context: context,
                icon: Icons.settings_outlined,
                onPressed: onSettingsTap,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    return Row(
      children: [
        _buildHeaderActionButton(
          context: context,
          icon: Icons.chevron_left_rounded,
          iconSize: 24,
          onPressed: onBackTap,
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.headlineLg.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
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

        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
        trailing ?? const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required BuildContext context,
    required IconData icon,
    VoidCallback? onPressed,
    double iconSize = 20,
    bool badge = false,
  }) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
              top: 8,
              right: 8,
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
    );
  }
}
