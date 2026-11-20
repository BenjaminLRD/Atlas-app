import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/widgets/common/app_button.dart';
import 'package:atlas/main.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
  });

  group('WorkoutSessionScreen Layout & CTA Visibility Tests', () {
    final viewports = [
      const Size(320, 800),
      const Size(360, 800),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'WorkoutSessionScreen renders CTA cleanly without overflow at ${size.width}x${size.height}',
        (WidgetTester tester) async {
          tester.view.physicalSize = Size(size.width * 3.0, size.height * 3.0);
          tester.view.devicePixelRatio = 3.0;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: const WorkoutSessionScreen(),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.takeException(), isNull);

          final ctaFinder = find.textContaining('START SET');
          expect(ctaFinder, findsOneWidget);

          final ctaButtonFinder = find.ancestor(
            of: ctaFinder,
            matching: find.byType(AppButton),
          );
          final ctaSize = tester.getSize(ctaButtonFinder);
          expect(ctaSize.width, greaterThanOrEqualTo(44.0));
          expect(ctaSize.height, greaterThanOrEqualTo(44.0));

          // Verify CTA is within viewport bounds
          final ctaCenter = tester.getCenter(ctaFinder);
          expect(ctaCenter.dy, lessThanOrEqualTo(size.height));
          expect(ctaCenter.dy, greaterThan(0.0));

          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
        },
      );
    }

    testWidgets(
      'MainShell keeps the bottom nav visible on the Workouts overview tab',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const MainShell()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Workouts'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The overview is not a running session, so navigation stays usable.
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Diet Plan'), findsOneWidget);
        expect(find.textContaining('START SET'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
