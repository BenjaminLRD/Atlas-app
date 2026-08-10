import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'data/app_dependencies.dart';
import 'data/local_storage.dart';
import 'data/profile_provider.dart';
import 'providers/fitness_provider.dart';
import 'widgets/common/ambient_background.dart';
import 'widgets/top_app_bar.dart';
import 'widgets/ai_chat_button.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diet_plan_screen.dart';
import 'screens/workout_session_screen.dart';
import 'screens/workout_history_screen.dart';
import 'screens/profile_screen.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding/user_goal_setup_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  // Initialize dependency composition root
  AppDependencies.instance;
  runApp(const AizawlGymApp());
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  _parseThemeMode(LocalStorage.getThemeModeString()),
);

ThemeMode _parseThemeMode(String val) {
  if (val == 'light') return ThemeMode.light;
  if (val == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
}

class AizawlGymApp extends StatelessWidget {
  const AizawlGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Aizawl Gym',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: (LocalStorage.isLoggedIn() || FitnessProvider.instance.isAuthenticated)
              ? (LocalStorage.isGoalOnboardingCompleted() ||
                      LocalStorage.getGoal() != null ||
                      FitnessProvider.instance.currentGoal != null
                  ? const MainShell()
                  : const UserGoalSetupFlow())
              : const LoginScreen(),
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
  int _currentIndex = 0;
  final ProfileProvider _profileProvider = AppDependencies.instance.profileProvider;
  final FitnessProvider _fitnessProvider = FitnessProvider.instance;

  final List<Widget> _screens = const [
    DashboardScreen(),
    DietPlanScreen(),
    WorkoutSessionScreen(
      workoutName: 'Leg Day - Hypertrophy',
      workoutId: 'leg_day_hypertrophy_01',
    ),
    WorkoutHistoryScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, filledIcon: Icons.dashboard_rounded, label: 'Summary'),
    _NavItem(icon: Icons.restaurant_outlined, filledIcon: Icons.restaurant_rounded, label: 'Diet Plan'),
    _NavItem(icon: Icons.fitness_center_outlined, filledIcon: Icons.fitness_center_rounded, label: 'Workouts'),
    _NavItem(icon: Icons.show_chart_rounded, filledIcon: Icons.analytics_rounded, label: 'Progress'),
    _NavItem(icon: Icons.person_outline_rounded, filledIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for profile and central fitness state changes
    _profileProvider.addListener(_onProfileChanged);
    _fitnessProvider.addListener(_onFitnessChanged);
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: AmbientBackground(
        child: Stack(
          children: [
            // Screen content
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),

            // Top App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: CustomTopAppBar(
                  onProfileUpdated: () {
                    _profileProvider.reload();
                  },
                ),
              ),
            ),

            // Global Floating AI Coach Button safely calculated above bottom nav and safe area
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 84,
              right: 18,
              child: const AiChatButton(),
            ),

            // Bottom Nav Bar with safe area calculation
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: _buildBottomNavBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isActive = _currentIndex == index;

          if (isActive) {
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  item.filledIcon,
                  color: AppColors.onPrimary,
                  size: 24,
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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
