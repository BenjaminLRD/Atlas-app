import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:atlas/navigation/app_navigation.dart';
import 'package:atlas/main.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    await AppDependencies.instance.profileProvider.updateProfile(
      UserProfile.defaultProfile(email: 'benjamin@example.com').copyWith(
        name: 'Benjamin LRD',
        fitnessGoal: 'Hypertrophy',
        gender: 'Male',
        height: '175',
        weight: '72',
      ),
    );

    AppNavigation.syncTab(0);
  });

  Widget buildTestableApp({
    Size? surfaceSize,
    ThemeMode themeMode = ThemeMode.dark,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: surfaceSize ?? const Size(390, 844),
        padding: const EdgeInsets.only(top: 44, bottom: 34),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const MainShell(),
      ),
    );
  }

  group('Phase 5: Navigation Improvements & Responsiveness Tests', () {
    testWidgets(
      '1. Smart Back Behavior: Pressing back when drawer is open closes drawer first without switching tab',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Diet Plan (Nutrition) tab (Index 1)
        await tester.tap(find.byIcon(Icons.restaurant_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(AppNavigation.currentTabNotifier.value, equals(1));

        // Open Drawer
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AppDrawer), findsOneWidget);

        // Simulate Back button invocation (e.g. system back)
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Verify: Drawer is closed, but tab is STILL Diet Plan (index 1)
        expect(find.byType(AppDrawer), findsNothing);
        expect(AppNavigation.currentTabNotifier.value, equals(1));
      },
    );

    testWidgets(
      '2. Smart Back Behavior: Pressing back when drawer is closed on non-root tab returns to Home tab',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Community tab (index 3)
        await tester.tap(find.byIcon(Icons.groups_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(AppNavigation.currentTabNotifier.value, equals(3));

        // Simulate Back button press
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify: Returned to Home / Summary tab (index 0)
        expect(AppNavigation.currentTabNotifier.value, equals(0));
        expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      },
    );

    testWidgets(
      '3. State Preservation: Switching tabs preserves scroll position and loaded state',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll down on Dashboard tab
        final dashboardScrollable = find.byKey(
          const PageStorageKey('dashboard_scroll_view'),
        );
        expect(dashboardScrollable, findsOneWidget);
        await tester.drag(dashboardScrollable, const Offset(0, -300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final scrollableFinder = find
            .descendant(
              of: dashboardScrollable,
              matching: find.byType(Scrollable),
            )
            .first;
        final scrollableState = tester.state<ScrollableState>(scrollableFinder);
        final initialOffset = scrollableState.position.pixels;
        expect(initialOffset, greaterThan(100));

        // Switch to Profile tab
        await tester.tap(find.byIcon(Icons.person_outline_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(AppNavigation.currentTabNotifier.value, equals(4));

        // Switch back to Dashboard (Summary) tab
        await tester.tap(find.byIcon(Icons.dashboard_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(AppNavigation.currentTabNotifier.value, equals(0));

        // Verify scroll offset is preserved
        final restoredScrollableFinder = find
            .descendant(
              of: dashboardScrollable,
              matching: find.byType(Scrollable),
            )
            .first;
        final restoredScrollableState = tester.state<ScrollableState>(
          restoredScrollableFinder,
        );
        expect(
          restoredScrollableState.position.pixels,
          closeTo(initialOffset, 1.0),
        );
      },
    );

    testWidgets(
      '4. Responsive Verification: 320px phone screen renders MainShell & AppDrawer with ZERO overflow',
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

        // Open Drawer at 320px
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '5. Responsive Verification: 360px phone screen renders MainShell & AppDrawer with ZERO overflow',
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

        // Open Drawer at 360px
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '6. Responsive Verification: 768px tablet portrait renders MainShell & AppDrawer with ZERO overflow',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(768, 1024));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(768, 1024)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Open Drawer at 768px
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '7. Responsive Verification: 1024px tablet landscape renders MainShell & AppDrawer with ZERO overflow',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 768));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableApp(surfaceSize: const Size(1024, 768)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MainShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Open Drawer at 1024px
        await tester.tap(find.byTooltip('Open navigation menu').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
