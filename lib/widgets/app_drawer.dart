import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/gamification_service.dart';
import '../data/local_storage.dart';
import '../data/profile_provider.dart';
import '../main.dart' show themeModeNotifier;
import '../navigation/app_navigation.dart';
import 'common/app_image.dart';

/// Premium, high-contrast custom Navigation Drawer for Atlas.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  /// Static helper to open the drawer from any widget context
  static void open(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final ProfileProvider _profileProvider =
      AppDependencies.instance.profileProvider;
  final GamificationService _gamificationService = GamificationService();

  @override
  void initState() {
    super.initState();
    _profileProvider.addListener(_onStateUpdated);
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onStateUpdated);
    super.dispose();
  }

  void _onStateUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Drawer width: max 340px, or 82% of screen width
    final drawerWidth = min(screenWidth * 0.82, 340.0);

    // Dynamic high-contrast palettes for Dark & Light modes with frosted glass transparency
    final drawerBg = isDark
        ? const Color(0xFF101315).withValues(alpha: 0.88)
        : const Color(0xFFF6FAF7).withValues(alpha: 0.92);
    final borderColor = isDark
        ? const Color(0xFF262D28).withValues(alpha: 0.8)
        : const Color(0xFFD4E0D6).withValues(alpha: 0.9);

    return Semantics(
      label: 'Navigation Menu',
      child: Drawer(
        width: drawerWidth,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: drawerBg,
                border: Border(right: BorderSide(color: borderColor, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(4, 0),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.12 : 0.05,
                    ),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Profile Header
                    _buildProfileHeader(context, topInset),

                    // Header divider
                    Divider(height: 1, thickness: 1, color: borderColor),

                    // 2. Grouped Navigation Sections List
                    Expanded(
                      child: ValueListenableBuilder<AppNavDestination>(
                        valueListenable:
                            AppNavigation.activeDestinationNotifier,
                        builder: (context, activeDest, _) {
                          return ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              for (final section in AppNavigation.sections) ...[
                                _buildSectionHeader(context, section.title),
                                const SizedBox(height: 4),
                                for (final item in section.items) ...[
                                  _buildDrawerItem(
                                    context: context,
                                    item: item,
                                    isActive: activeDest == item,
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                const SizedBox(height: 14),
                              ],
                            ],
                          );
                        },
                      ),
                    ),

                    // Footer divider
                    Divider(height: 1, thickness: 1, color: borderColor),

                    // 3. Brand Footer with Theme Switcher & Version
                    _buildDrawerFooter(context, bottomInset),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive Profile Header with live dynamic data or helpful fallback
  Widget _buildProfileHeader(BuildContext context, double topInset) {
    final isDark = context.isDarkMode;

    final rawName = _profileProvider.isShowcaseIdentity
        ? ProfileProvider.showcaseSelfLabel
        : _profileProvider.name.trim();
    final rawGoal = _profileProvider.fitnessGoal.trim();
    final avatarPic = _profileProvider.displayProfilePic;

    // Check if user has set up profile
    final bool hasProfile = rawName.isNotEmpty;

    final String displayName = hasProfile ? rawName : 'Set up profile';

    // Gamification Level & Rank
    final progress = _gamificationService.getProgress();
    final int level = (progress.totalXP / 500).floor() + 1;
    final String rankName =
        progress.currentRank.isNotEmpty && progress.currentRank != 'Unranked'
        ? '${progress.currentRank} ${progress.currentDivision}'.trim()
        : 'Level $level';

    // Subtitle string
    final String subtitleText;
    if (hasProfile) {
      final goalDisplay = rawGoal.isNotEmpty ? rawGoal : 'Hypertrophy';
      subtitleText = '$goalDisplay • $rankName';
    } else {
      subtitleText = 'Complete your fitness journey';
    }

    final headerBg = isDark ? const Color(0xFF161A1C) : const Color(0xFFE8EFE9);
    final cardBg = isDark ? const Color(0xFF1C2224) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF2C3830)
        : const Color(0xFFCFDCD1);

    final titleColor = isDark
        ? const Color(0xFFF2F6F3)
        : const Color(0xFF152219);
    final subtitleColor = hasProfile
        ? AppColors.primary
        : (isDark ? const Color(0xFF90A195) : const Color(0xFF4D6054));
    final actionColor = isDark
        ? const Color(0xFF9FB0A5)
        : const Color(0xFF45584C);

    return Container(
      padding: EdgeInsets.only(
        top: topInset + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(color: headerBg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            AppNavigation.navigate(context, AppNavDestination.profile);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with Emerald Glow / Border
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: AppImage.avatar(
                      imageUrl: avatarPic.isNotEmpty ? avatarPic : null,
                      radius: 23,
                      name: _profileProvider.isShowcaseIdentity
                          ? null
                          : hasProfile
                          ? rawName
                          : 'AG',
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name, Goal & Rank subtitle + View Profile link
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Profile',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: actionColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: actionColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Uppercase section header with emerald dot accent
  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = context.isDarkMode;

    final headerColor = isDark
        ? const Color(0xFF7D8F83)
        : const Color(0xFF385241);

    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 10, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: headerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual interactive drawer item with active indicator and badge
  Widget _buildDrawerItem({
    required BuildContext context,
    required AppNavDestination item,
    required bool isActive,
  }) {
    final isDark = context.isDarkMode;

    final activeBg = isDark
        ? AppColors.primaryContainer.withValues(alpha: 0.22)
        : const Color(0xFFD7EEDC);

    final activeBorderColor = isDark
        ? AppColors.primary.withValues(alpha: 0.55)
        : AppColors.primary.withValues(alpha: 0.7);

    final titleColor = isActive
        ? (isDark ? Colors.white : const Color(0xFF0F2615))
        : (isDark ? const Color(0xFFE4EDE6) : const Color(0xFF152219));

    final subtitleColor = isActive
        ? (isDark ? const Color(0xFFB8C9BC) : const Color(0xFF2C4A33))
        : (isDark ? const Color(0xFF7D8F83) : const Color(0xFF4D6054));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          AppNavigation.navigate(context, item);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeBorderColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : (isDark
                            ? const Color(0xFF1C2224)
                            : const Color(0xFFDFE9E1)),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? AppColors.onPrimary
                      : (isDark
                            ? const Color(0xFFCFDCD1)
                            : const Color(0xFF1F3526)),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (item.badge != null) ...[
                          const SizedBox(width: 6),
                          _buildBadge(context, item.badge!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small accent badge (e.g. AI, XP, HOT)
  Widget _buildBadge(BuildContext context, String badgeText) {
    Color badgeBg;
    Color badgeFg;

    switch (badgeText.toUpperCase()) {
      case 'AI':
        badgeBg = const Color(0xFF00B0FF).withValues(alpha: 0.2);
        badgeFg = const Color(0xFF00B0FF);
        break;
      case 'XP':
        badgeBg = const Color(0xFFFFB300).withValues(alpha: 0.2);
        badgeFg = const Color(0xFFFFB300);
        break;
      case 'HOT':
        badgeBg = const Color(0xFFFF5252).withValues(alpha: 0.2);
        badgeFg = const Color(0xFFFF5252);
        break;
      default:
        badgeBg = AppColors.primary.withValues(alpha: 0.2);
        badgeFg = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badgeText,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: badgeFg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Drawer Footer with live Theme Mode toggle and App Version
  Widget _buildDrawerFooter(BuildContext context, double bottomInset) {
    final isDark = context.isDarkMode;

    final footerBg = isDark ? const Color(0xFF161A1C) : const Color(0xFFE8EFE9);
    final buttonBg = isDark ? const Color(0xFF22292B) : const Color(0xFFD7E2D9);
    final buttonBorder = isDark
        ? const Color(0xFF333E37)
        : const Color(0xFFBACABA);
    final versionColor = isDark
        ? const Color(0xFF7D8F83)
        : const Color(0xFF4D6054);
    final textColor = isDark
        ? const Color(0xFFE4EDE6)
        : const Color(0xFF152219);

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        bottom: max(bottomInset, 12),
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(color: footerBg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Version & Brand
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Atlas',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'v1.0.0 Pro Edition',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: versionColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Theme Switcher Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
              themeModeNotifier.value = nextMode;
              LocalStorage.saveThemeModeString(isDark ? 'light' : 'dark');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: buttonBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDark ? 'Dark' : 'Light',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
