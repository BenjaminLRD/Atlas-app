import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'data/app_dependencies.dart';
import 'data/local_storage.dart';
import 'data/profile_provider.dart';
import 'widgets/top_app_bar.dart';
import 'widgets/ai_chat_button.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diet_plan_screen.dart';
import 'screens/workout_plan_screen.dart';
import 'screens/profile_screen.dart';

import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  // Initialize dependency composition root
  AppDependencies.instance;
  runApp(const AizawlGymApp());
}

class AizawlGymApp extends StatelessWidget {
  const AizawlGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aizawl Gym',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: LocalStorage.isLoggedIn() ? const MainShell() : const LoginScreen(),
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    DietPlanScreen(),
    WorkoutPlanScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, filledIcon: Icons.dashboard_rounded, label: 'Summary'),
    _NavItem(icon: Icons.restaurant_outlined, filledIcon: Icons.restaurant_rounded, label: 'Diet Plan'),
    _NavItem(icon: Icons.fitness_center_outlined, filledIcon: Icons.fitness_center_rounded, label: 'Workouts'),
    _NavItem(icon: Icons.person_outline_rounded, filledIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for profile changes to rebuild the shell (top bar, etc.)
    _profileProvider.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
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

          // Frosted Glass Translucent Premium AI Chat Button
          const Positioned(
            bottom: 96,
            right: 20,
            child: AiChatButton(),
          ),

          // Bottom Nav Bar
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _buildBottomNavBar(),
            ),
          ),
        ],
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
