import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/navigation/app_navigation.dart';
import 'package:atlas/screens/body_composition_screen.dart';
import 'package:atlas/screens/cardio_history_screen.dart';
import 'package:atlas/screens/checkout_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/custom_workouts_screen.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/screens/friends_screen.dart';
import 'package:atlas/screens/health_dashboard_screen.dart';
import 'package:atlas/screens/hydration_screen.dart';
import 'package:atlas/screens/meal_prep_hub_screen.dart';
import 'package:atlas/screens/meal_preps_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/ranked_screen.dart';
import 'package:atlas/screens/settings_screen.dart';
import 'package:atlas/screens/subscription_screen.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_history_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/models/subscription_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen a showcase visitor can reach, in Showcase Mode, and
/// fails on any exception, any sign-in prompt, or visible error text. This is a
/// widget-level smoke test: it proves the screens build and show content, not
/// that a real phone, camera, GPS or backend works.
const _nl = '\n';

/// First line of the error plus the source line of the offending widget, so a
/// failure points at code instead of just "overflowed".
String _where(FlutterErrorDetails d) {
  final t = d.toString();
  final loc = RegExp(r'file:///\S+?\.dart:\d+:\d+')
      .allMatches(t)
      .map((m) => m.group(0)!.replaceAll('file:///E:/apps/workou/Atlas/', ''))
      .take(1)
      .join();
  return '${d.exceptionAsString().split(_nl).first} @ $loc';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screens = <String, Widget Function(BuildContext)>{
    for (final d in AppNavDestination.all)
      if (d.routeBuilder != null) 'drawer:${d.id}': d.routeBuilder!,
    'drawer:cardio_tracking': AppNavDestination.cardioTracking.routeBuilder!,
    'tab:home': (_) => const DashboardScreen(),
    'tab:diet': (_) => const DietPlanScreen(),
    'tab:workouts': (_) => const WorkoutOverviewScreen(),
    'tab:community': (_) => const CommunityScreen(),
    'tab:profile': (_) => const ProfileScreen(),
    'health': (_) => const HealthDashboardScreen(),
    'hydration': (_) => const HydrationScreen(),
    'cardio_history': (_) => const CardioHistoryScreen(),
    'friends': (_) => const FriendsScreen(),
    'ranked': (_) => const RankedScreen(),
    'settings': (_) => const SettingsScreen(),
    'plans': (_) => const SubscriptionScreen(),
    'checkout': (_) => CheckoutScreen(plan: PlanCatalog.plus),
    'workout_history': (_) => const WorkoutHistoryScreen(),
    'weekly_plan': (_) => const WeeklyWorkoutPlanScreen(),
    'custom_workouts': (_) => const CustomWorkoutsScreen(),
    'meal_prep_hub': (_) => const MealPrepHubScreen(),
    'meal_plans': (_) => const MealPrepsScreen(),
    'body_composition': (_) => const BodyCompositionScreen(),
  };

  for (final showcase in [true, false]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} opens cleanly (showcase=$showcase)', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await LocalStorage.init();
        await LocalStorage.setShowcaseModeEnabled(showcase);
        addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) =>
            errors.add(_where(d));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(builder: (c) => e.value(c)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        Object? ex;
        while ((ex = tester.takeException()) != null) {
          errors.add('$ex'.split(_nl).first);
        }
        FlutterError.onError = old;
        expect(errors, isEmpty, reason: '${e.key}: $errors');
        final text = find
            .byType(Text)
            .evaluate()
            .map((x) => ((x.widget as Text).data ?? '').toLowerCase())
            .join(' | ');
        if (showcase) {
          expect(
            text,
            isNot(contains('sign in to')),
            reason: '${e.key} asks for sign-in',
          );
          expect(text, isNot(contains('something went wrong')), reason: e.key);
        }
        expect(text, isNot(contains('exception')), reason: e.key);
        // Not a blank page.
        expect(
          find.byType(Text).evaluate().length,
          greaterThan(2),
          reason: '${e.key} looks empty',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
