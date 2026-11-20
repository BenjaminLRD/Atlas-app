import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/main.dart';
import 'package:atlas/widgets/ai_chat_button.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:atlas/widgets/common/app_button.dart';
import 'package:atlas/widgets/common/app_chip.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/workout_history_screen.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/screens/ai_coach_screen.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
  });

  /// Helper calculating relative luminance & WCAG contrast ratio
  double calculateContrast(Color foreground, Color background) {
    double getLuminance(Color color) {
      double transform(double channel) {
        return channel <= 0.03928
            ? channel / 12.92
            : pow((channel + 0.055) / 1.055, 2.4).toDouble();
      }

      final r = transform(color.r);
      final g = transform(color.g);
      final b = transform(color.b);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    final l1 = getLuminance(foreground);
    final l2 = getLuminance(background);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  Widget buildAppWrapper(
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    double fontScale = 1.0,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(fontScale),
        size: const Size(390, 844),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: child is Scaffold ? child : Scaffold(body: child),
      ),
    );
  }

  group('Phase 8: Accessibility & WCAG Contrast Tests', () {
    test('WCAG AA / AAA contrast ratios met across Light and Dark themes', () {
      // Light mode contrast checks
      final lightTextPrimaryOnSurface = calculateContrast(
        AppColors.textPrimary,
        AppColors.surface,
      );
      expect(
        lightTextPrimaryOnSurface,
        greaterThanOrEqualTo(7.0),
      ); // WCAG AAA (≥ 7.0)

      final lightTextPrimaryOnBg = calculateContrast(
        AppColors.textPrimary,
        AppColors.background,
      );
      expect(lightTextPrimaryOnBg, greaterThanOrEqualTo(7.0)); // WCAG AAA

      final lightTextSecondaryOnSurface = calculateContrast(
        AppColors.textSecondary,
        AppColors.surface,
      );
      expect(
        lightTextSecondaryOnSurface,
        greaterThanOrEqualTo(4.5),
      ); // WCAG AA (≥ 4.5)

      final lightWhiteOnPrimary = calculateContrast(
        AppColors.onPrimary,
        AppColors.primary,
      );
      expect(
        lightWhiteOnPrimary,
        greaterThanOrEqualTo(4.0),
      ); // WCAG AA for bold interactive CTA buttons (≥ 3.0 required)

      // Dark mode contrast checks
      final darkTextPrimaryOnBg = calculateContrast(
        AppColors.darkTextPrimary,
        AppColors.darkBackground,
      );
      expect(darkTextPrimaryOnBg, greaterThanOrEqualTo(7.0)); // WCAG AAA

      final darkTextSecondaryOnSurface = calculateContrast(
        AppColors.darkTextSecondary,
        AppColors.darkSurface,
      );
      expect(darkTextSecondaryOnSurface, greaterThanOrEqualTo(4.5)); // WCAG AA

      final darkPrimaryOnSurface = calculateContrast(
        AppColors.darkPrimary,
        AppColors.darkSurface,
      );
      expect(darkPrimaryOnSurface, greaterThanOrEqualTo(4.5)); // WCAG AA
    });

    testWidgets(
      'Touch targets minimum 44px on primary buttons, chips, and FAB',
      (tester) async {
        await tester.pumpWidget(
          buildAppWrapper(
            Column(
              children: [
                AppButton.primary(label: 'Start Workout', onPressed: () {}),
                AppButton.secondary(label: 'Cancel', onPressed: () {}),
                AppChip.selectable(
                  label: 'Cardio',
                  isSelected: true,
                  onTap: () {},
                ),
                const AiChatButton(),
              ],
            ),
          ),
        );
        await tester.pump();

        final buttonSize = tester.getSize(find.text('Start Workout'));
        expect(buttonSize.height, greaterThanOrEqualTo(14)); // inner text

        final primaryButtonBox = tester.renderObject<RenderBox>(
          find.byType(AppButton).first,
        );
        expect(primaryButtonBox.size.height, greaterThanOrEqualTo(44.0));

        final chipBox = tester.renderObject<RenderBox>(find.byType(AppChip));
        expect(chipBox.size.height, greaterThanOrEqualTo(44.0));

        final fabBox = tester.renderObject<RenderBox>(
          find.byType(AiChatButton),
        );
        expect(fabBox.size.height, greaterThanOrEqualTo(44.0));
        expect(fabBox.size.width, greaterThanOrEqualTo(44.0));
      },
    );

    testWidgets(
      'Dark/Light switching dynamically applies appropriate theme without errors',
      (tester) async {
        await tester.pumpWidget(
          ValueListenableBuilder<ThemeMode>(
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Toggle to dark mode
        themeModeNotifier.value = ThemeMode.dark;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);

        // Toggle back to light mode
        themeModeNotifier.value = ThemeMode.light;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Font scaling (1.3x and 1.5x) preserves layout without RenderFlex overflows',
      (tester) async {
        for (final scale in [1.3, 1.5]) {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildAppWrapper(const DashboardScreen(), fontScale: scale),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          final dynamic exception = tester.takeException();
          expect(exception, isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );
  });

  group('Phase 8: Multi-Screen & Multi-Device Verification Matrix', () {
    final viewports = [
      const Size(320, 640), // 320px
      const Size(360, 740), // 360px
      const Size(390, 844), // 390px
      const Size(412, 915), // 412px
    ];

    testWidgets(
      'Dashboard Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildAppWrapper(const DashboardScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'Profile Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildAppWrapper(const ProfileScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'Progress Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildAppWrapper(const WorkoutHistoryScreen()),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          final dynamic exception = tester.takeException();
          expect(exception, isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'Nutrition Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildAppWrapper(const DietPlanScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'Workout Session Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildAppWrapper(
              WorkoutSessionScreen(
                workoutName: 'Leg Day - Hypertrophy',
                workoutId: 'leg_01',
                onExit: () {},
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'AI Coach Screen renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildAppWrapper(const AICoachScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );

    testWidgets(
      'AppDrawer renders across all 4 device sizes with 0 overflows',
      (tester) async {
        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final scaffoldKey = GlobalKey<ScaffoldState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                key: scaffoldKey,
                drawer: const AppDrawer(),
                body: const Center(child: Text('Home')),
              ),
            ),
          );
          await tester.pump();

          scaffoldKey.currentState?.openDrawer();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(AppDrawer), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );
  });
}
