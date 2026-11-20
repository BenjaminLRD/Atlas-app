import 'package:flutter/material.dart';
import '../screens/atlas_intelligence_dashboard_screen.dart';
import '../screens/ai_coach_screen.dart';
import '../screens/personalization_insights_screen.dart';
import '../screens/unified_food_scanner_screen.dart';
import '../screens/challenges_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/onboarding/user_goal_setup_flow.dart';
import '../screens/ranked_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/weekly_workout_plan_screen.dart';
import '../screens/equipment_setup_screen.dart';
import '../screens/exercise_library_screen.dart';
import '../screens/weight_gain_plan_screen.dart';
import '../screens/cardio_activity_screen.dart';
import '../screens/community_screen.dart';
import '../screens/health_dashboard_screen.dart';

/// The 5 primary logical navigation sections across the Atlas app.
enum AppNavSection {
  main('MAIN'),
  training('TRAINING'),
  community('COMMUNITY'),
  nutritionAndGoals('NUTRITION & GOALS'),
  app('APP');

  final String title;
  const AppNavSection(this.title);
}

/// Type of navigation destination (bottom tab switch vs secondary pushed route).
enum AppNavDestinationType { bottomTab, route }

/// Centralized navigation destination model and single source of truth.
class AppNavDestination {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final AppNavSection section;
  final AppNavDestinationType destinationType;
  final int? tabIndex;
  final WidgetBuilder? routeBuilder;
  final String? badge;

  const AppNavDestination({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
    required this.destinationType,
    this.tabIndex,
    this.routeBuilder,
    this.badge,
  });

  /// Alias getter for description
  String get description => subtitle;

  /// Whether this destination switches the bottom navigation bar
  bool get isBottomTab => destinationType == AppNavDestinationType.bottomTab;

  // =========================================================================
  // PRE-DEFINED SINGLETON DESTINATIONS
  // =========================================================================

  // MAIN
  static const AppNavDestination home = AppNavDestination(
    id: 'home',
    title: 'Home',
    subtitle: 'Daily overview, streak & quick stats',
    icon: Icons.dashboard_rounded,
    section: AppNavSection.main,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 0,
  );

  static const AppNavDestination nutrition = AppNavDestination(
    id: 'nutrition',
    title: 'Nutrition',
    subtitle: 'Macros, calories & nutrient distribution',
    icon: Icons.restaurant_rounded,
    section: AppNavSection.main,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 1,
  );

  static const AppNavDestination workouts = AppNavDestination(
    id: 'workouts',
    title: 'Workouts',
    subtitle: 'Active training protocols & exercises',
    icon: Icons.fitness_center_rounded,
    section: AppNavSection.main,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 2,
  );

  static const AppNavDestination progress = AppNavDestination(
    id: 'progress',
    title: 'Progress & Analytics',
    subtitle: 'Volume metrics, PRs & workout history',
    icon: Icons.analytics_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 4,
  );

  // TRAINING
  static final AppNavDestination aiCoach = AppNavDestination(
    id: 'ai_coach',
    title: 'Atlas AI',
    subtitle: 'Your fitness intelligence partner',
    icon: Icons.psychology_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    badge: 'AI',
    routeBuilder: (context) => const AICoachScreen(),
  );

  static final AppNavDestination personalizationInsights = AppNavDestination(
    id: 'personalization_insights',
    title: 'AI Predictive Insights',
    subtitle: 'Machine learning discoveries & habit analysis',
    icon: Icons.psychology_alt_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    badge: 'ML',
    routeBuilder: (context) => const PersonalizationInsightsScreen(),
  );

  static final AppNavDestination ranked = AppNavDestination(
    id: 'ranked',
    title: 'Ranked Mode',
    subtitle: 'Compete, earn XP and climb the leaderboard',
    icon: Icons.emoji_events_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    badge: 'XP',
    routeBuilder: (context) => const RankedScreen(),
  );

  static final AppNavDestination goals = AppNavDestination(
    id: 'goals',
    title: 'Goals & Programs',
    subtitle: 'Hypertrophy, strength & endurance tracks',
    icon: Icons.track_changes_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const UserGoalSetupFlow(),
  );

  static final AppNavDestination equipment = AppNavDestination(
    id: 'equipment',
    title: 'Equipment Setup',
    subtitle: 'Customize workouts based on your gym access',
    icon: Icons.tune_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const EquipmentSetupScreen(),
  );

  // FUTURE TRAINING FEATURES (Pluggable with zero drawer redesign)
  static final AppNavDestination workoutVideos = AppNavDestination(
    id: 'workout_videos',
    title: 'Workout Videos',
    subtitle: 'Form guides, follow-along sessions & tutorials',
    icon: Icons.play_circle_outline_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const ExerciseLibraryScreen(),
  );

  static final AppNavDestination cardioTracking = AppNavDestination(
    id: 'cardio_tracking',
    title: 'Cardio',
    subtitle: 'Outdoor run & ride tracking',
    icon: Icons.directions_run_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const CardioActivityScreen(),
  );

  static final AppNavDestination healthDashboard = AppNavDestination(
    id: 'health_dashboard',
    title: 'Health Dashboard',
    subtitle: 'Track activity & recovery',
    icon: Icons.favorite_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    badge: 'NEW',
    routeBuilder: (context) => const HealthDashboardScreen(),
  );

  static final AppNavDestination heartRate = AppNavDestination(
    id: 'heart_rate',
    title: 'Heart Rate',
    subtitle: 'BPM zones, recovery stats & sensor sync',
    icon: Icons.favorite_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const HealthDashboardScreen(),
  );

  static final AppNavDestination exerciseLibrary = AppNavDestination(
    id: 'exercise_library',
    title: 'Exercise Library',
    subtitle: 'Search 500+ movements, muscle targets & cues',
    icon: Icons.library_books_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const ExerciseLibraryScreen(),
  );

  static final AppNavDestination machineAvailability = AppNavDestination(
    id: 'machine_availability',
    title: 'Machine Availability',
    subtitle: 'Real-time gym floor equipment occupancy',
    icon: Icons.fitness_center_rounded,
    section: AppNavSection.training,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const WeeklyWorkoutPlanScreen(),
  );

  // COMMUNITY
  static const AppNavDestination community = AppNavDestination(
    id: 'community',
    title: 'Community',
    subtitle: 'Share workouts, meals and achievements',
    icon: Icons.groups_rounded,
    section: AppNavSection.main,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 3,
  );

  static final AppNavDestination leaderboard = AppNavDestination(
    id: 'leaderboard',
    title: 'Leaderboard',
    subtitle: 'Global and gym member standings',
    icon: Icons.local_fire_department_rounded,
    section: AppNavSection.community,
    destinationType: AppNavDestinationType.route,
    badge: 'HOT',
    routeBuilder: (context) => const RankedScreen(),
  );

  static final AppNavDestination achievements = AppNavDestination(
    id: 'achievements',
    title: 'Achievements',
    subtitle: 'Milestones, badges & season challenges',
    icon: Icons.military_tech_rounded,
    section: AppNavSection.community,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const ChallengesScreen(),
  );

  // FUTURE COMMUNITY FEATURES (Pluggable with zero drawer redesign)
  static final AppNavDestination communityFeed = AppNavDestination(
    id: 'community_feed',
    title: 'Community Feed',
    subtitle: 'Explore posts, workouts & member highlights',
    icon: Icons.dynamic_feed_rounded,
    section: AppNavSection.community,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const CommunityScreen(),
  );

  static final AppNavDestination challenges = AppNavDestination(
    id: 'challenges',
    title: 'Challenges',
    subtitle: 'Monthly fitness trials & community events',
    icon: Icons.emoji_events_rounded,
    section: AppNavSection.community,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const ChallengesScreen(),
  );

  // NUTRITION & GOALS
  static const AppNavDestination mealPlans = AppNavDestination(
    id: 'meal_plans',
    title: 'Meal Plans',
    subtitle: 'Custom target macros & food recipes',
    icon: Icons.menu_book_rounded,
    section: AppNavSection.nutritionAndGoals,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 1,
  );

  static final AppNavDestination foodDatabase = AppNavDestination(
    id: 'food_database',
    title: 'Food Database',
    subtitle: 'Scan barcodes & explore verified foods',
    icon: Icons.qr_code_scanner_rounded,
    section: AppNavSection.nutritionAndGoals,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) =>
        const UnifiedFoodScannerScreen(initialMode: UnifiedScanMode.barcode),
  );

  static final AppNavDestination weightGoal = AppNavDestination(
    id: 'weight_goal',
    title: 'Weight Goal Program',
    subtitle: 'Caloric surplus, transformation timeline & meal schedule',
    icon: Icons.monitor_weight_rounded,
    section: AppNavSection.nutritionAndGoals,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const WeightGainPlanScreen(),
  );

  // FUTURE NUTRITION & GOAL FEATURES
  static final AppNavDestination weightGainProgram = AppNavDestination(
    id: 'weight_gain_program',
    title: 'Weight Gain Program',
    subtitle: 'Surplus calories, mass hypertrophy & macro plan',
    icon: Icons.trending_up_rounded,
    section: AppNavSection.nutritionAndGoals,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const WeightGainPlanScreen(),
  );

  // FUTURE MAIN FEATURES
  static final AppNavDestination steps = AppNavDestination(
    id: 'steps',
    title: 'Steps',
    subtitle: 'Daily step counter, distance & active time',
    icon: Icons.directions_walk_rounded,
    section: AppNavSection.main,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 0,
  );

  // APP
  static const AppNavDestination profile = AppNavDestination(
    id: 'profile',
    title: 'Profile',
    subtitle: 'Account settings, tier level & biometrics',
    icon: Icons.person_rounded,
    section: AppNavSection.app,
    destinationType: AppNavDestinationType.bottomTab,
    tabIndex: 4,
  );

  static final AppNavDestination notifications = AppNavDestination(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Workout alerts, reminders & updates',
    icon: Icons.notifications_rounded,
    section: AppNavSection.app,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const NotificationsScreen(),
  );

  static final AppNavDestination intelligenceDashboard = AppNavDestination(
    id: 'intelligence_dashboard',
    title: 'Intelligence Cloud',
    subtitle: 'Research ingestion, pattern discovery & model telemetry',
    icon: Icons.auto_awesome_rounded,
    section: AppNavSection.app,
    destinationType: AppNavDestinationType.route,
    badge: 'RAG',
    routeBuilder: (context) => const AtlasIntelligenceDashboardScreen(),
  );

  static final AppNavDestination settings = AppNavDestination(
    id: 'settings',
    title: 'Settings',
    subtitle: 'Theme, measurement units & preferences',
    icon: Icons.settings_rounded,
    section: AppNavSection.app,
    destinationType: AppNavDestinationType.route,
    routeBuilder: (context) => const SettingsScreen(),
  );

  /// All registered destinations in structured order
  static List<AppNavDestination> get all => [
    home,
    nutrition,
    workouts,
    community,
    cardioTracking,
    aiCoach,
    personalizationInsights,
    ranked,
    progress,
    goals,
    equipment,
    healthDashboard,
    leaderboard,
    achievements,
    mealPlans,
    foodDatabase,
    weightGoal,
    profile,
    notifications,
    settings,
  ];

  /// Grouped items by section
  static List<AppNavDestination> bySection(AppNavSection section) {
    return all.where((item) => item.section == section).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNavDestination &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Navigation section structure model for UI rendering.
class AppNavSectionGroup {
  final AppNavSection section;
  final String title;
  final List<AppNavDestination> items;

  const AppNavSectionGroup({
    required this.section,
    required this.title,
    required this.items,
  });
}

/// Centralized navigation system controller and single source of truth.
class AppNavigation {
  /// Reactive notifier for currently active destination
  static final ValueNotifier<AppNavDestination> activeDestinationNotifier =
      ValueNotifier<AppNavDestination>(AppNavDestination.home);

  /// Reactive notifier for current bottom tab index
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier<int>(0);

  /// Global callback registered by MainShell to switch bottom tabs
  static void Function(int tabIndex)? onTabSwitch;

  /// Logical grouped navigation sections conforming to the app's information architecture
  static List<AppNavSectionGroup> get sections => [
    AppNavSectionGroup(
      section: AppNavSection.main,
      title: AppNavSection.main.title,
      items: AppNavDestination.bySection(AppNavSection.main),
    ),
    AppNavSectionGroup(
      section: AppNavSection.training,
      title: AppNavSection.training.title,
      items: AppNavDestination.bySection(AppNavSection.training),
    ),
    AppNavSectionGroup(
      section: AppNavSection.community,
      title: AppNavSection.community.title,
      items: AppNavDestination.bySection(AppNavSection.community),
    ),
    AppNavSectionGroup(
      section: AppNavSection.nutritionAndGoals,
      title: AppNavSection.nutritionAndGoals.title,
      items: AppNavDestination.bySection(AppNavSection.nutritionAndGoals),
    ),
    AppNavSectionGroup(
      section: AppNavSection.app,
      title: AppNavSection.app.title,
      items: AppNavDestination.bySection(AppNavSection.app),
    ),
  ];

  /// Synchronize the active destination when bottom tab changes
  static void syncTab(int tabIndex) {
    currentTabNotifier.value = tabIndex;
    switch (tabIndex) {
      case 0:
        activeDestinationNotifier.value = AppNavDestination.home;
        break;
      case 1:
        activeDestinationNotifier.value = AppNavDestination.nutrition;
        break;
      case 2:
        activeDestinationNotifier.value = AppNavDestination.workouts;
        break;
      case 3:
        activeDestinationNotifier.value = AppNavDestination.community;
        break;
      case 4:
        activeDestinationNotifier.value = AppNavDestination.profile;
        break;
      default:
        activeDestinationNotifier.value = AppNavDestination.home;
    }
  }

  /// Primary centralized navigation entrypoint
  static void navigate(BuildContext context, AppNavDestination destination) {
    // 1. Close drawer if open
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState?.isDrawerOpen ?? false) {
      scaffoldState?.closeDrawer();
    }

    // 2. Handle bottom tab navigation
    if (destination.isBottomTab && destination.tabIndex != null) {
      // Avoid duplicate screens: Pop back to root MainShell if on a secondary route
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      onTabSwitch?.call(destination.tabIndex!);
      syncTab(destination.tabIndex!);
      return;
    }

    // 3. Handle secondary page route navigation
    if (destination.destinationType == AppNavDestinationType.route &&
        destination.routeBuilder != null) {
      activeDestinationNotifier.value = destination;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: destination.routeBuilder!,
          settings: RouteSettings(name: '/${destination.id}'),
        ),
      );
    }
  }

  /// Alias for navigate for backwards compatibility
  static void navigateTo(BuildContext context, AppNavDestination destination) {
    navigate(context, destination);
  }
}
