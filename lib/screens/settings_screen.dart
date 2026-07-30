import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../data/profile_provider.dart';
import '../main.dart';
import '../widgets/common/ambient_background.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_dialog.dart';
import 'login_screen.dart';
import 'workout_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileProvider _profileProvider;
  late String _selectedThemeMode;

  bool _workoutRemindersEnabled = true;
  bool _mealRemindersEnabled = true;
  bool _goalAchievementsEnabled = true;
  bool _generalNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _selectedThemeMode = LocalStorage.getThemeModeString();
    _workoutRemindersEnabled = LocalStorage.getBool(
      'pref_workout_reminders',
      defaultValue: true,
    );
    _mealRemindersEnabled = LocalStorage.getBool(
      'pref_meal_reminders',
      defaultValue: true,
    );
    _goalAchievementsEnabled = LocalStorage.getBool(
      'pref_goal_achievements',
      defaultValue: true,
    );
    _generalNotificationsEnabled = LocalStorage.getBool(
      'pref_general_notifications',
      defaultValue: true,
    );
  }

  void _showFeedbackSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.bodySm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onThemeChanged(String mode) {
    setState(() {
      _selectedThemeMode = mode;
    });
    LocalStorage.saveThemeModeString(mode);
    if (mode == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    } else if (mode == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else {
      themeModeNotifier.value = ThemeMode.system;
    }
    final modeLabel = mode == 'system'
        ? 'System Default'
        : mode == 'light'
        ? 'Light Mode'
        : 'Dark Mode';
    _showFeedbackSnackBar('Theme updated to $modeLabel');
  }

  Future<void> _onWorkoutRemindersToggled(bool value) async {
    setState(() {
      _workoutRemindersEnabled = value;
    });
    await LocalStorage.saveBool('pref_workout_reminders', value);
    final userProfile = _profileProvider.userProfile;
    userProfile.notificationsEnabled = value;
    await _profileProvider.updateProfile(userProfile);
    _showFeedbackSnackBar(
      value ? 'Workout reminders enabled' : 'Workout reminders disabled',
    );
  }

  void _showUnitsModal() {
    final currentMass = _profileProvider.massUnit;
    final isMetric = currentMass.toLowerCase() == 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.appOutlineVariant.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Units Preference',
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 18,
                              color: context.appTextPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.appSurfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 18),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select measurement units used across workout and profile screens.',
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metric Option
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isMetric
                            ? AppColors.primaryContainer.withValues(alpha: 0.2)
                            : context.appSurfaceElevated,
                        leading: const Icon(
                          Icons.fitness_center_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Metric',
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Kilograms (kg), Centimeters (cm)',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        trailing: isMetric
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () async {
                          final profile = _profileProvider.userProfile;
                          profile.massUnit = 'kg';
                          profile.lengthUnit = 'cm';
                          await _profileProvider.updateProfile(profile);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (mounted) setState(() {});
                          _showFeedbackSnackBar(
                            'Units updated to Metric (kg, cm)',
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Imperial Option
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: !isMetric
                            ? AppColors.primaryContainer.withValues(alpha: 0.2)
                            : context.appSurfaceElevated,
                        leading: const Icon(
                          Icons.monitor_weight_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Imperial',
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Pounds (lbs), Inches (in)',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        trailing: !isMetric
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () async {
                          final profile = _profileProvider.userProfile;
                          profile.massUnit = 'lbs';
                          profile.lengthUnit = 'in';
                          await _profileProvider.updateProfile(profile);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (mounted) setState(() {});
                          _showFeedbackSnackBar(
                            'Units updated to Imperial (lbs, in)',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.appOutlineVariant.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notification Settings',
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 18,
                              color: context.appTextPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.appSurfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 18),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: Text(
                          'Workout Reminders',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Get notified before scheduled workouts',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        value: _workoutRemindersEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          setModalState(() => _workoutRemindersEnabled = val);
                          await _onWorkoutRemindersToggled(val);
                        },
                      ),
                      const Divider(height: 1),

                      SwitchListTile(
                        title: Text(
                          'Meal Reminders',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Receive reminders to log daily nutrition',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        value: _mealRemindersEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          setModalState(() => _mealRemindersEnabled = val);
                          setState(() => _mealRemindersEnabled = val);
                          await LocalStorage.saveBool(
                            'pref_meal_reminders',
                            val,
                          );
                          _showFeedbackSnackBar(
                            val
                                ? 'Meal reminders enabled'
                                : 'Meal reminders disabled',
                          );
                        },
                      ),
                      const Divider(height: 1),

                      SwitchListTile(
                        title: Text(
                          'Goal Achievements',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Notifications when reaching streak or volume goals',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        value: _goalAchievementsEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          setModalState(() => _goalAchievementsEnabled = val);
                          setState(() => _goalAchievementsEnabled = val);
                          await LocalStorage.saveBool(
                            'pref_goal_achievements',
                            val,
                          );
                          _showFeedbackSnackBar(
                            val
                                ? 'Goal achievement alerts enabled'
                                : 'Goal achievement alerts disabled',
                          );
                        },
                      ),
                      const Divider(height: 1),

                      SwitchListTile(
                        title: Text(
                          'General App Notifications',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'App updates and AI coach highlights',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                        value: _generalNotificationsEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          setModalState(
                            () => _generalNotificationsEnabled = val,
                          );
                          setState(() => _generalNotificationsEnabled = val);
                          await LocalStorage.saveBool(
                            'pref_general_notifications',
                            val,
                          );
                          _showFeedbackSnackBar(
                            val
                                ? 'General notifications enabled'
                                : 'General notifications disabled',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle Indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appOutlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Privacy & Security',
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 18,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.appSurfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    leading: const Icon(
                      Icons.policy_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Privacy Policy',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Read our data privacy commitment',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      _showTextDetailModal(
                        'Privacy Policy',
                        'Aizawl Gym prioritizes your data privacy. All biometric profiles, nutrition targets, and workout records are stored securely on device. We do not sell or share personal health telemetry with third parties.',
                      );
                    },
                  ),
                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(
                      Icons.gavel_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Terms of Service',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'App usage terms and conditions',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      _showTextDetailModal(
                        'Terms of Service',
                        'By using Aizawl Gym, you agree to follow safe athletic training practices. Consult a medical professional before initiating high-intensity weight training protocols.',
                      );
                    },
                  ),
                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(
                      Icons.storage_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Data Storage',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Local device storage verified',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LOCAL',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  ListTile(
                    leading: Icon(
                      Icons.download_outlined,
                      color: context.appTextSecondary,
                    ),
                    title: Text(
                      'Export Data',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                    subtitle: Text(
                      'Download training logs in CSV format',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Delete Account',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently erase account data',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Your data is safe" Encrypted Info Banner Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your data is safe',
                                style: AppTheme.bodySm.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'We use industry-standard encryption to keep your data secure.',
                                style: AppTheme.bodySm.copyWith(
                                  fontSize: 11,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTextDetailModal(String title, String content) {
    AppDialog.show(
      context: context,
      title: title,
      content: Text(
        content,
        style: AppTheme.bodySm.copyWith(
          fontSize: 13,
          height: 1.5,
          color: context.appTextPrimary,
        ),
      ),
    );
  }

  void _showHelpModal() {
    _showTextDetailModal(
      'Help & FAQ',
      '• How do I track workouts?\nTap the center elevated "Workouts" button to start an active workout session.\n\n• How do I update my profile?\nGo to Profile tab and tap "Update" on any bento card.\n\n• How is protein calculated?\nLogged meal items update your daily macro totals automatically.',
    );
  }

  void _showContactSupportModal() {
    _showTextDetailModal(
      'Contact Support',
      'Need assistance with your protocol or app setup?\n\nEmail: support@aizawlgym.com\nHours: Mon - Sat, 9:00 AM - 6:00 PM IST',
    );
  }

  Future<void> _handleLogout() async {
    await LocalStorage.setLoggedIn(false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final massUnit = _profileProvider.massUnit;
    final unitsLabel = massUnit.toLowerCase() == 'kg'
        ? 'Metric (kg, cm)'
        : 'Imperial (lbs, in)';

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'Settings',
        onBackTap: () => Navigator.maybePop(context),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Appearance Card (Theme Selector Only - Accent Color Section Removed)
              _buildAppearanceCard(context),
              const SizedBox(height: 14),

              // Preferences Card
              _buildPreferencesCard(context, unitsLabel: unitsLabel),
              const SizedBox(height: 14),

              // Support Card
              _buildSupportCard(context),
              const SizedBox(height: 14),

              // Logout Card
              _buildLogoutCard(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Appearance',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 17,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Theme Subtitle
          Text(
            'Theme',
            style: AppTheme.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Choose your preferred theme',
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Apple-style Segmented Theme Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.appOutlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                _buildSegmentButton(
                  context,
                  label: 'System',
                  icon: Icons.wb_sunny_outlined,
                  modeKey: 'system',
                ),
                _buildSegmentButton(
                  context,
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  modeKey: 'light',
                ),
                _buildSegmentButton(
                  context,
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  modeKey: 'dark',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String modeKey,
  }) {
    final isSelected = _selectedThemeMode == modeKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onThemeChanged(modeKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : context.appTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(
    BuildContext context, {
    required String unitsLabel,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Preferences',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 17,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildSettingsTile(
            context,
            icon: Icons.history_rounded,
            title: 'Workout History',
            subtitle: 'View recorded completed training logs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()),
              );
            },
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.straighten,
            title: 'Units',
            subtitle: unitsLabel,
            onTap: _showUnitsModal,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage your notification preferences',
            onTap: _showNotificationsModal,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.shield_outlined,
            title: 'Workout Reminders',
            subtitle: 'Get reminded about your workouts',
            trailing: Switch(
              value: _workoutRemindersEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: _onWorkoutRemindersToggled,
            ),
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.security_outlined,
            title: 'Privacy',
            subtitle: 'Manage your data and privacy',
            onTap: _showPrivacyModal,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.headset_mic_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Support',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 17,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            subtitle: 'Frequently asked questions & guides',
            onTap: _showHelpModal,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Contact Support',
            subtitle: 'Get assistance from our team',
            onTap: _showContactSupportModal,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return AppCard(
      onTap: _handleLogout,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.logout, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Text(
            'Logout',
            style: AppTheme.bodySm.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.error,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: context.appTextSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}
