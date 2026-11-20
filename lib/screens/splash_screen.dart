import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../main.dart';
import '../providers/fitness_provider.dart';
import '../services/cloud/auth_availability.dart';
import '../widgets/common/atlas_logo.dart';
import '../services/cloud/cloud_session.dart';
import '../services/onboarding_state_service.dart';
import 'login_screen.dart';
import 'onboarding/user_goal_setup_flow.dart';
import 'onboarding_screen.dart';

/// Premium Atlas Splash Screen orchestrating the startup decision tree.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _resolveStartupRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveStartupRoute() async {
    // Ensure smooth presentation animation has time to display
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final hasCompletedOnboarding = OnboardingStateService.instance
        .hasCompletedOnboarding();

    if (!hasCompletedOnboarding) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    // With accounts enabled, only a real session (or showcase mode) gets in;
    // the local "logged in" flag alone is not enough.
    final usesAccounts =
        CloudSession.client != null && !LocalStorage.isShowcaseModeEnabled();
    // A release build without Supabase has no real accounts: the stored
    // "logged in" flag may come from the old local fallback, so only
    // Showcase Mode counts.
    final isAuthenticated = AuthAvailability.accountsUnavailable
        ? LocalStorage.isShowcaseModeEnabled()
        : usesAccounts
        ? CloudSession.userId != null
        : LocalStorage.isLoggedIn() || FitnessProvider.instance.isAuthenticated;

    if (!isAuthenticated) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    final isGoalCompleted =
        LocalStorage.isGoalOnboardingCompleted() ||
        LocalStorage.getGoal() != null ||
        FitnessProvider.instance.currentGoal != null;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            isGoalCompleted ? const MainShell() : const UserGoalSetupFlow(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo mark
                    const AtlasLogoMark(size: 112, glow: true),
                    const SizedBox(height: 28),
                    // App Title
                    const AtlasWordmark(),
                    const SizedBox(height: 10),
                    // Subtitle
                    Text(
                      'Autonomous Personal Fitness Companion',
                      style: AppTheme.bodyMd.copyWith(
                        fontSize: 14,
                        color: context.appTextSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Minimal Loading Indicator
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
