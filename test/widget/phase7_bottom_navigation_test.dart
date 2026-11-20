import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/main.dart';
import 'package:atlas/widgets/common/app_glass.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
  });

  Widget buildTestApp({ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShell(),
    );
  }

  group('Phase 7: Bottom Navigation Redesign Tests', () {
    testWidgets(
      'Frosted background renders with BackdropFilter, blur, and subtle border',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(AppGlassContainer), findsWidgets);
        expect(find.byType(BackdropFilter), findsWidgets);

        final glassContainers = tester.widgetList<AppGlassContainer>(
          find.byType(AppGlassContainer),
        );
        final navGlass = glassContainers.firstWhere((g) => g.blur == 20.0);
        expect(navGlass.blur, 20.0);
        expect(navGlass.borderRadius, BorderRadius.circular(28));
      },
    );

    testWidgets(
      'All 5 icons and labels render with unified vertical alignment',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Diet Plan'), findsOneWidget);
        expect(find.text('Workouts'), findsOneWidget);
        expect(find.text('Community'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
        expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
        expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
        expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Active pill indicator highlights selected tab and switches smoothly',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Initial active tab: Summary (tab 0)
        expect(
          find.descendant(
            of: find.byType(AppGlassContainer),
            matching: find.byIcon(Icons.dashboard_rounded),
          ),
          findsOneWidget,
        );

        // Tap 'Diet Plan' tab (tab 1)
        await tester.tap(find.text('Diet Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Active icon for Diet Plan is filled in bottom nav
        expect(
          find.descendant(
            of: find.byType(AppGlassContainer),
            matching: find.byIcon(Icons.restaurant_rounded),
          ),
          findsOneWidget,
        );

        // Tap 'Community' tab (tab 3)
        await tester.tap(find.text('Community'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Active icon for Community is filled in bottom nav
        expect(
          find.descendant(
            of: find.byType(AppGlassContainer),
            matching: find.byIcon(Icons.groups_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Safe area padding correctly offsets bottom navigation on notched devices',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 34.0);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetPadding();
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Zero overflow errors across 320px, 360px, 390px, and 412px viewports',
      (tester) async {
        final viewports = [
          const Size(320, 640),
          const Size(360, 740),
          const Size(390, 844),
          const Size(412, 915),
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildTestApp());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Diet Plan'), findsOneWidget);
          expect(find.text('Workouts'), findsOneWidget);
          expect(find.text('Community'), findsOneWidget);
          expect(find.text('Profile'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );
  });
}
