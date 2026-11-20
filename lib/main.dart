import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'data/app_dependencies.dart';
import 'data/local_storage.dart';
import 'data/profile_provider.dart';
import 'providers/fitness_provider.dart';
import 'services/steps/step_counter_service.dart';
import 'widgets/common/ambient_background.dart';
import 'widgets/common/app_glass.dart';
import 'widgets/app_drawer.dart';
import 'navigation/app_navigation.dart';
import 'widgets/floating_action_bubble_stack.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diet_plan_screen.dart';
import 'screens/workout_overview_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';

import 'dart:ui';
import 'config/app_config.dart';
import 'screens/splash_screen.dart';
import 'services/monitoring/monitoring_manager.dart';
import 'services/supabase/supabase_service.dart';
import 'services/cloud/cloud_session.dart';
import 'services/health/health_service.dart';
import 'services/health/platform_health_reader.dart';
import 'services/health/platform_health_service.dart';

void main() async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend with credentials passed via --dart-define
  await SupabaseService.instance.initialize();

  // Initialize monitoring subsystem with active environment configuration
  final config = AppConfig.current;
  await MonitoringManager.instance.initialize(config);

  // Global Flutter Error Hook (widgets, rendering, framework)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    MonitoringManager.instance.recordError(
      details.exception,
      details.stack,
      reason: 'FlutterError.onError (${details.library})',
      fatal: false,
    );
  };

  // Global Async & PlatformDispatcher Error Hook (async futures, background failures)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    MonitoringManager.instance.recordError(
      error,
      stack,
      reason: 'PlatformDispatcher.onError',
      fatal: true,
    );
    return true;
  };

  await LocalStorage.init();
  // Initialize dependency composition root
  AppDependencies.instance;

  // Phones read real data from Apple Health / Health Connect.
  if (PlatformHealthReader.isSupportedPlatform) {
    HealthService.setInstance(PlatformHealthService());
  }

  // Count steps with the phone's own step counter. This only checks the
  // permission; the system dialog is shown when the user asks for it.
  if (StepCounterService.isSupportedPlatform) {
    unawaited(StepCounterService.instance.start());
  }

  // Signed-in users: push changes made offline and pull from other devices.
  if (CloudSession.client != null) {
    unawaited(FitnessProvider.instance.restoreSession());
  }

  startupStopwatch.stop();
  MonitoringManager.instance.performance.recordAppStartup(
    duration: startupStopwatch.elapsed,
    isColdLaunch: true,
  );

  runApp(const AtlasApp());
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  _parseThemeMode(LocalStorage.getThemeModeString()),
);

ThemeMode _parseThemeMode(String val) {
  if (val == 'light') return ThemeMode.light;
  if (val == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
}

class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key});

  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back in the foreground the step permission may have been changed in the
  // system settings; going to the background saves the step count.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!StepCounterService.isSupportedPlatform) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(StepCounterService.instance.onResumed());
    } else if (state == AppLifecycleState.paused) {
      unawaited(StepCounterService.instance.onPaused());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Atlas',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  int _currentIndex = 0;
  final ProfileProvider _profileProvider =
      AppDependencies.instance.profileProvider;
  final FitnessProvider _fitnessProvider = FitnessProvider.instance;

  late final List<Widget> _screens = [
    const DashboardScreen(key: PageStorageKey('dashboard_screen_tab')),
    const DietPlanScreen(key: PageStorageKey('diet_plan_screen_tab')),
    const WorkoutOverviewScreen(key: PageStorageKey('workout_overview_tab')),
    const CommunityScreen(
      key: PageStorageKey('community_screen_tab'),
    ),
    const ProfileScreen(key: PageStorageKey('profile_screen_tab')),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.dashboard_outlined,
      filledIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.restaurant_outlined,
      filledIcon: Icons.restaurant_rounded,
      label: 'Diet Plan',
    ),
    _NavItem(
      icon: Icons.fitness_center_outlined,
      filledIcon: Icons.fitness_center_rounded,
      label: 'Workouts',
    ),
    _NavItem(
      icon: Icons.groups_outlined,
      filledIcon: Icons.groups_rounded,
      label: 'Community',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      filledIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for profile and central fitness state changes
    _profileProvider.addListener(_onProfileChanged);
    _fitnessProvider.addListener(_onFitnessChanged);

    // Register tab switcher with AppNavigation
    AppNavigation.onTabSwitch = (index) {
      if (mounted) {
        setState(() => _currentIndex = index);
      }
    };
  }

  @override
  void dispose() {
    AppNavigation.onTabSwitch = null;
    _fitnessProvider.removeListener(_onFitnessChanged);
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onFitnessChanged() {
    if (mounted) setState(() {});
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    AppNavigation.syncTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? bottomInset + 4 : 12.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If drawer is open, close drawer first
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }

        // 2. If on a secondary tab, return to the Home tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          AppNavigation.syncTab(0);
          return;
        }

        // 3. If on Home tab, allow default system pop
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: context.appBackground,
        drawer: const AppDrawer(),
        body: PageStorage(
          bucket: _pageStorageBucket,
          child: AmbientBackground(
            child: Stack(
              children: [
                // Screen content
                IndexedStack(index: _currentIndex, children: _screens),

                // Global Floating Actions (Scanner Button + AI Coach Button) safely calculated above bottom nav/CTA and safe area
                Positioned(
                  bottom: navBottomOffset + 74,
                  right: 18,
                  child: const FloatingActionBubbleStack(),
                ),

                // Bottom Nav Bar
                Positioned(
                  bottom: navBottomOffset,
                  left: 12,
                  right: 12,
                  child: Center(child: _buildBottomNavBar()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final isDark = context.isDarkMode;

    return Container(
      width: MediaQuery.of(context).size.width * 0.94,
      constraints: const BoxConstraints(maxWidth: 420),
      child: AppGlassContainer.bottomNav(
        context: context,
        blur: 20.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isActive = _currentIndex == index;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onTabTapped(index),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppColors.primary.withValues(alpha: 0.12),
                  highlightColor: AppColors.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Pill Indicator for Icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: 48,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark
                                      ? AppColors.primary.withValues(
                                          alpha: 0.25,
                                        )
                                      : AppColors.secondary)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: isActive
                                ? Border.all(
                                    color: isDark
                                        ? AppColors.darkPrimary.withValues(
                                            alpha: 0.4,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              isActive ? item.filledIcon : item.icon,
                              color: isActive
                                  ? (isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.primary)
                                  : (isDark
                                        ? AppColors.darkMutedText
                                        : AppColors.textSecondary),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Label with unified baseline alignment
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? (isDark ? Colors.white : AppColors.primary)
                                  : (isDark
                                        ? AppColors.darkMutedText
                                        : AppColors.textSecondary),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData filledIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
  });
}
