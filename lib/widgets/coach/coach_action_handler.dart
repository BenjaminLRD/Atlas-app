import 'package:flutter/material.dart';
import '../../screens/diet_plan_screen.dart';
import '../../screens/weekly_workout_plan_screen.dart';
import '../../screens/ranked_screen.dart';
import '../../screens/onboarding/user_goal_setup_flow.dart';

/// Centralized action handler for executing recommendation routes without
/// coupling routing logic inside UI components.
class CoachActionHandler {
  const CoachActionHandler();

  /// Resolves the provided action string/route and performs navigation.
  static void handleAction(BuildContext context, String? actionRoute) {
    if (actionRoute == null || actionRoute.isEmpty) return;

    final normalized = actionRoute.toLowerCase().trim();

    if (normalized.contains('nutrition') || normalized.contains('diet')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DietPlanScreen()),
      );
    } else if (normalized.contains('workout') || normalized.contains('training') || normalized.contains('plan')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeeklyWorkoutPlanScreen()),
      );
    } else if (normalized.contains('progress') || normalized.contains('rank')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RankedScreen()),
      );
    } else if (normalized.contains('goal')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserGoalSetupFlow()),
      );
    } else {
      // Fallback feedback for unmapped custom routes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening action: $actionRoute'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
