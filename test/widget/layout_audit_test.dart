import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/ai_coach_screen.dart';
import 'package:atlas/screens/body_composition_screen.dart';
import 'package:atlas/screens/cardio_activity_screen.dart';
import 'package:atlas/screens/cardio_history_screen.dart';
import 'package:atlas/screens/challenges_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/screens/equipment_setup_screen.dart';
import 'package:atlas/screens/exercise_library_screen.dart';
import 'package:atlas/screens/friends_screen.dart';
import 'package:atlas/screens/health_dashboard_screen.dart';
import 'package:atlas/screens/hydration_screen.dart';
import 'package:atlas/screens/notifications_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/ranked_screen.dart';
import 'package:atlas/screens/settings_screen.dart';
import 'package:atlas/screens/subscription_screen.dart';
import 'package:atlas/screens/wearable_devices_screen.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_history_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the app-wide layout audit: every major screen, at a
/// narrow phone width with large text and at a normal width, must lay out with
/// no RenderFlex overflow, in normal and Showcase Mode. A failure names the
/// source line of the overflowing widget.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final screens = <String, Widget Function()>{
    'Dashboard': () => const DashboardScreen(),
    'Diet': () => const DietPlanScreen(),
    'WorkoutOverview': () => const WorkoutOverviewScreen(),
    'Community': () => const CommunityScreen(),
    'Profile': () => const ProfileScreen(),
    'Cardio': () => const CardioActivityScreen(),
    'CardioHistory': () => const CardioHistoryScreen(),
    'Health': () => const HealthDashboardScreen(),
    'Hydration': () => const HydrationScreen(),
    'Ranked': () => const RankedScreen(),
    'Friends': () => const FriendsScreen(),
    'Challenges': () => const ChallengesScreen(),
    'Settings': () => const SettingsScreen(),
    'Subscription': () => const SubscriptionScreen(),
    'Notifications': () => const NotificationsScreen(),
    'Wearables': () => const WearableDevicesScreen(),
    'WeeklyPlan': () => const WeeklyWorkoutPlanScreen(),
    'History': () => const WorkoutHistoryScreen(),
    'ExerciseLibrary': () => const ExerciseLibraryScreen(),
    'Equipment': () => const EquipmentSetupScreen(),
    'BodyComp': () => const BodyCompositionScreen(),
    'AICoach': () => const AICoachScreen(),
    'Drawer': () => const Scaffold(body: AppDrawer()),
  };
  for (final showcase in [false, true]) {
    for (final cfg in const [
      [320.0, 640.0, 1.5],
      [360.0, 740.0, 1.0],
    ]) {
      for (final e in screens.entries) {
        testWidgets(
          '${e.key} has no overflow (showcase=$showcase, ${cfg[0].toInt()}dp, text x${cfg[2]})',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            await LocalStorage.init();
            if (showcase) await LocalStorage.setShowcaseModeEnabled(true);
            final errs = <FlutterErrorDetails>[];
            final old = FlutterError.onError;
            FlutterError.onError = errs.add;
            addTearDown(() => FlutterError.onError = old);
            tester.view.physicalSize = Size(cfg[0], cfg[1]);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(cfg[0], cfg[1]),
                      textScaler: TextScaler.linear(cfg[2]),
                    ),
                    child: e.value(),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              final sc = find.byType(Scrollable);
              if (sc.evaluate().isNotEmpty) {
                for (var i = 0; i < 8; i++) {
                  await tester.drag(sc.first, const Offset(0, -450));
                  await tester.pump(const Duration(milliseconds: 50));
                }
              }
            } catch (ex) {
              fail('${e.key} could not be shown: $ex');
            }
            final seen = <String>{};
            final found = <String>[];
            for (final d in errs) {
              final t = d.toString();
              final m = RegExp(
                r'overflowed by ([0-9.]+) pixels on the (\w+)',
              ).firstMatch(t);
              if (m == null) continue;
              final loc = RegExp(r'file:///\S+?\.dart:\d+:\d+')
                  .allMatches(t)
                  .map(
                    (x) => x
                        .group(0)!
                        .replaceAll('file:///E:/apps/workou/Atlas/', ''),
                  )
                  .take(1)
                  .join();
              final cr = RegExp(r'creator: .+').firstMatch(t)?.group(0) ?? '';
              final k = '$loc ${m.group(2)} $cr';
              if (seen.add(k)) found.add('$k (${m.group(1)}px)');
            }
            expect(found, isEmpty, reason: 'overflow in ${e.key}');
          },
        );
      }
    }
  }

  group('long user-written text', () {
    const long =
        'Maximilian Alexandrovich Wolfeschlegelsteinhausenbergerdorff the Third';
    final screens = <String, Widget Function()>{
      'Dashboard': () => const DashboardScreen(),
      'Profile': () => const ProfileScreen(),
      'Drawer': () => const Scaffold(body: AppDrawer()),
      'Friends': () => const FriendsScreen(),
    };
    for (final e in screens.entries) {
      testWidgets('${e.key} copes with a very long name', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await LocalStorage.init();
        await AppDependencies.instance.profileProvider.updateField(
          'name',
          long,
        );
        await AppDependencies.instance.profileProvider.updateField(
          'bio',
          'x' * 400,
        );
        final errs = <FlutterErrorDetails>[];
        final old = FlutterError.onError;
        FlutterError.onError = errs.add;
        addTearDown(() => FlutterError.onError = old);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: e.value(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final overflow = errs
            .map((d) => d.toString())
            .where((t) => t.contains('overflowed'))
            .toList();
        expect(overflow, isEmpty);
      });
    }
  });
}
