import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/widgets/common/motivational_quote_bottom_sheet.dart';
import 'package:atlas/widgets/common/app_image.dart';
import 'package:atlas/widgets/common/app_button.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
  });

  group('Quote of the Day Modal Layout & Image Loading Tests', () {
    const viewports = [
      Size(320, 800),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'Modal renders without overflow at ${size.width}x${size.height}',
        (WidgetTester tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: MotivationalQuoteBottomSheet()),
            ),
          );
          await tester.pumpAndSettle();

          // Verify no RenderFlex errors occurred
          expect(tester.takeException(), isNull);

          // Verify header and buttons are rendered
          expect(find.text('QUOTE OF THE DAY'), findsOneWidget);
          expect(find.text('Another Quote'), findsOneWidget);
          expect(find.text('Share'), findsOneWidget);

          // Verify bottom action buttons size & tappable
          final anotherQuoteFinder = find.ancestor(
            of: find.text('Another Quote'),
            matching: find.byType(AppButton),
          );
          final shareFinder = find.ancestor(
            of: find.text('Share'),
            matching: find.byType(AppButton),
          );

          expect(anotherQuoteFinder, findsOneWidget);
          expect(shareFinder, findsOneWidget);

          final anotherQuoteSize = tester.getSize(anotherQuoteFinder);
          final shareSize = tester.getSize(shareFinder);

          expect(anotherQuoteSize.height, greaterThanOrEqualTo(44.0));
          expect(shareSize.height, greaterThanOrEqualTo(44.0));

          // Test tapping Another Quote button
          await tester.tap(find.text('Another Quote'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);

          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        },
      );
    }

    testWidgets('AppImage renders CachedNetworkImage for valid imageUrl', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: AppImage(
              imageUrl: 'https://example.com/test_quote.jpg',
              fallbackText: 'Goku',
              fallbackIcon: Icons.auto_awesome_rounded,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppImage renders fallback UI for null or empty imageUrl', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AppImage(
                imageUrl: null,
                fallbackText: 'Goku',
                fallbackIcon: Icons.auto_awesome_rounded,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify fallback icon and styled fallback label render
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.text('GOKU'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppImage handles invalid imageUrl with fallback UI in test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AppImage(
                imageUrl: 'https://invalid-url.example/broken.jpg',
                fallbackText: 'Saitama',
                fallbackIcon: Icons.fitness_center_rounded,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modal applies safe area bottom inset correctly', (
      WidgetTester tester,
    ) async {
      const bottomInset = 34.0;
      tester.view.padding = FakeViewPadding(bottom: bottomInset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: MotivationalQuoteBottomSheet()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final modalContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Another Quote'),
              matching: find.byType(Container),
            )
            .last,
      );

      final margin = modalContainer.margin as EdgeInsets;
      expect(margin.bottom, greaterThan(12.0));

      tester.view.resetPadding();
    });
  });
}
