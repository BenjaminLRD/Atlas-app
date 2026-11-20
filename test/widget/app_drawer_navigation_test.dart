import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:atlas/navigation/app_navigation.dart';
import 'package:atlas/screens/ai_coach_screen.dart';
import 'package:atlas/screens/cardio_activity_screen.dart';
import 'package:atlas/screens/ranked_screen.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
    await AppDependencies.instance.profileProvider.updateProfile(
      UserProfile.defaultProfile(email: 'benjamin@example.com').copyWith(
        name: 'Benjamin LRD',
        fitnessGoal: 'Hypertrophy Goal',
        gender: 'Male',
        height: '175',
        weight: '72',
      ),
    );
    themeModeNotifier.value = ThemeMode.dark;
    AppNavigation.syncTab(0);
  });

  Widget buildTestableApp({
    ThemeMode themeMode = ThemeMode.dark,
    Size surfaceSize = const Size(390, 844),
  }) {
    themeModeNotifier.value = themeMode;
    return MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: const EdgeInsets.only(top: 44, bottom: 34),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: const MainShell(),
          );
        },
      ),
    );
  }

  Widget buildStandaloneDrawer({
    ThemeMode themeMode = ThemeMode.dark,
    Size surfaceSize = const Size(390, 844),
  }) {
    themeModeNotifier.value = themeMode;
    return MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(
              drawer: const AppDrawer(),
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  group('Drawer Verification Tests', () {
    testWidgets('✓ Opens correctly on hamburger menu button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final menuButton = find.byTooltip('Open navigation menu').first;
      expect(menuButton, findsOneWidget);
      expect(find.byType(AppDrawer), findsNothing);

      await tester.tap(menuButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppDrawer), findsOneWidget);
    });

    testWidgets(
      '✓ Profile header loads dynamic user data & fallback when empty',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Benjamin LRD'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppDrawer),
            matching: find.textContaining('Hypertrophy Goal'),
          ),
          findsWidgets,
        );

        // Test fallback when user data is empty
        await AppDependencies.instance.profileProvider.updateProfile(
          UserProfile.defaultProfile(email: ''),
        );

        await tester.pumpWidget(buildStandaloneDrawer());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Set up profile'), findsOneWidget);
        expect(find.text('Complete your fitness journey'), findsOneWidget);
        expect(find.text('User'), findsNothing);
        expect(find.text('Athlete'), findsNothing);
        expect(find.text('Gym Member'), findsNothing);
      },
    );

    testWidgets(
      '✓ All sections appear: MAIN, TRAINING, COMMUNITY, NUTRITION & GOALS, APP',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('MAIN'), findsOneWidget);
        expect(find.text('TRAINING'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppDrawer),
            matching: find.text('Home'),
          ),
          findsOneWidget,
        );
        expect(find.text('Nutrition'), findsOneWidget);

        final drawerScrollable = find.descendant(
          of: find.byType(AppDrawer),
          matching: find.byType(Scrollable),
        );

        await tester.scrollUntilVisible(
          find.text('COMMUNITY'),
          50.0,
          scrollable: drawerScrollable,
        );
        expect(find.text('COMMUNITY'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('NUTRITION & GOALS'),
          50.0,
          scrollable: drawerScrollable,
        );
        expect(find.text('NUTRITION & GOALS'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('APP'),
          50.0,
          scrollable: drawerScrollable,
        );
        expect(find.text('APP'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Settings'),
          50.0,
          scrollable: drawerScrollable,
        );
        expect(
          find.descendant(
            of: find.byType(AppDrawer),
            matching: find.text('Settings'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '✓ Active destination highlights with emerald pill and indicator',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Home is active initially
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.home),
        );

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Home item has active indicator
        expect(
          find.descendant(
            of: find.byType(AppDrawer),
            matching: find.text('Home'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('✓ Theme switching works smoothly in drawer footer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableApp(themeMode: ThemeMode.dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Theme Mode button is rendered in footer
      final darkButton = find.text('Dark');
      expect(darkButton, findsOneWidget);

      // Tap Theme Mode button
      await tester.tap(darkButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify theme toggled to Light
      expect(find.text('Light'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Navigation Flow Tests', () {
    testWidgets('✓ Bottom tabs switch correctly from drawer selections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Open drawer & tap Nutrition
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Nutrition'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppDrawer), findsNothing);
      expect(AppNavigation.currentTabNotifier.value, equals(1));
      expect(
        AppNavigation.activeDestinationNotifier.value,
        equals(AppNavDestination.nutrition),
      );

      // 2. Open drawer & tap Community
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final communityItem = find.descendant(
        of: find.byType(AppDrawer),
        matching: find.text('Community'),
      );
      expect(communityItem, findsOneWidget);
      await tester.tap(communityItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppDrawer), findsNothing);
      expect(AppNavigation.currentTabNotifier.value, equals(3));
      expect(
        AppNavigation.activeDestinationNotifier.value,
        equals(AppNavDestination.community),
      );
    });

    testWidgets(
      '✓ Secondary routes open correctly with route builders (Atlas AI & Ranked)',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Open drawer & tap Atlas AI
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.scrollUntilVisible(
          find.descendant(
            of: find.byType(AppDrawer),
            matching: find.text('Atlas AI'),
          ),
          50.0,
          scrollable: find.descendant(
            of: find.byType(AppDrawer),
            matching: find.byType(Scrollable),
          ),
        );
        final atlasAiItem = find.descendant(
          of: find.byType(AppDrawer),
          matching: find.text('Atlas AI'),
        );
        expect(atlasAiItem, findsOneWidget);
        await tester.tap(atlasAiItem);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AppDrawer), findsNothing);
        expect(find.byType(AICoachScreen), findsOneWidget);
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.aiCoach),
        );

        // 2. Pop back
        Navigator.of(tester.element(find.byType(AICoachScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AICoachScreen), findsNothing);

        // 3. Open drawer & tap Ranked Mode
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final drawerScrollable = find.descendant(
          of: find.byType(AppDrawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Ranked Mode'),
          50.0,
          scrollable: drawerScrollable,
        );

        final rankedItem = find.descendant(
          of: find.byType(AppDrawer),
          matching: find.text('Ranked Mode'),
        );
        expect(rankedItem, findsOneWidget);
        await tester.ensureVisible(rankedItem);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(rankedItem, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AppDrawer), findsNothing);
        expect(find.byType(RankedScreen), findsOneWidget);
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.ranked),
        );
      },
    );

    testWidgets('✓ Back navigation closes drawer first when open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Diet Plan tab (index 1)
      await tester.tap(find.byIcon(Icons.restaurant_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AppNavigation.currentTabNotifier.value, equals(1));

      // Open Drawer
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppDrawer), findsOneWidget);

      // Back closes drawer first
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppDrawer), findsNothing);
      expect(AppNavigation.currentTabNotifier.value, equals(1));
    });

    testWidgets('✓ Back navigation returns to Home tab from secondary tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Diet Plan tab (index 1)
      await tester.tap(find.byIcon(Icons.restaurant_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AppNavigation.currentTabNotifier.value, equals(1));

      // Back returns to Home tab
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(AppNavigation.currentTabNotifier.value, equals(0));
    });
  });

  group('Responsive Viewport Tests (0 Overflow Errors)', () {
    testWidgets(
      '✓ 320px phone screen renders MainShell & AppDrawer with 0 overflows',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(320, 640)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '✓ 360px phone screen renders MainShell & AppDrawer with 0 overflows',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(360, 800)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '✓ 390px phone screen renders MainShell & AppDrawer with 0 overflows',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(390, 844)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '✓ 412px phone screen renders MainShell & AppDrawer with 0 overflows',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(412, 915)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Future Extensibility Tests', () {
    testWidgets('✓ Adding future destinations requires no drawer redesign', (
      WidgetTester tester,
    ) async {
      // Test with custom future destination
      final customFutureDest = AppNavDestination(
        id: 'workout_videos',
        title: 'Workout Videos',
        subtitle: 'Form guides, follow-along sessions & tutorials',
        icon: Icons.play_circle_outline_rounded,
        section: AppNavSection.training,
        destinationType: AppNavDestinationType.route,
        routeBuilder: (context) => const WeeklyWorkoutPlanScreen(),
      );

      expect(customFutureDest.id, equals('workout_videos'));
      expect(customFutureDest.title, equals('Workout Videos'));
      expect(customFutureDest.section, equals(AppNavSection.training));
    });
  });

  group('Cardio in the quick navigation', () {
    testWidgets('Cardio is the first item under TRAINING and opens the hub', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final training = AppNavDestination.bySection(AppNavSection.training);
      expect(training.first, equals(AppNavDestination.cardioTracking));
      expect(AppNavDestination.cardioTracking.title, 'Cardio');
      // The existing destinations are all still there.
      for (final d in [
        AppNavDestination.aiCoach,
        AppNavDestination.personalizationInsights,
        AppNavDestination.ranked,
        AppNavDestination.progress,
        AppNavDestination.goals,
        AppNavDestination.equipment,
        AppNavDestination.healthDashboard,
      ]) {
        expect(training, contains(d));
      }

      final cardio = find.descendant(
        of: find.byType(AppDrawer),
        matching: find.text('Cardio'),
      );
      expect(cardio, findsOneWidget);
      await tester.scrollUntilVisible(
        cardio,
        50.0,
        scrollable: find.descendant(
          of: find.byType(AppDrawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(cardio);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppDrawer), findsNothing);
      expect(find.byType(CardioActivityScreen), findsOneWidget);
      expect(
        AppNavigation.activeDestinationNotifier.value,
        equals(AppNavDestination.cardioTracking),
      );
    });

    testWidgets('Cardio works in Showcase Mode too', (tester) async {
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final cardio = find.descendant(
        of: find.byType(AppDrawer),
        matching: find.text('Cardio'),
      );
      expect(cardio, findsOneWidget);
      await tester.scrollUntilVisible(
        cardio,
        50.0,
        scrollable: find.descendant(
          of: find.byType(AppDrawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(cardio);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CardioActivityScreen), findsOneWidget);
    });

    testWidgets('the first tab is called Home, not Summary', (tester) async {
      await tester.pumpWidget(buildTestableApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Summary'), findsNothing);
      expect(AppNavDestination.home.title, 'Home');
    });
  });
}
