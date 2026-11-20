import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/widgets/common/app_button.dart';
import 'package:atlas/widgets/common/app_card.dart';
import 'package:atlas/widgets/common/app_chip.dart';
import 'package:atlas/widgets/common/app_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCard Redesign Tests', () {
    testWidgets('renders with 20px radius, subtle border, and soft shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AppCard(child: Text('Card Content'))),
        ),
      );

      final cardFinder = find.byType(AppCard);
      expect(cardFinder, findsOneWidget);

      final containerFinder = find
          .descendant(of: cardFinder, matching: find.byType(Container))
          .first;

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      // 20px radius
      expect(decoration.borderRadius, BorderRadius.circular(20.0));
      // Subtle green border #D7EEDB
      expect((decoration.border as Border).top.color, AppColors.cardBorder);
      // White surface in Light Mode
      expect(decoration.color, const Color(0xFFFFFFFF));
      // Soft shadow
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.boxShadow!.first.blurRadius, 16);
    });
  });

  group('AppButton Redesign Tests', () {
    testWidgets(
      'AppButton.primary renders with green filled background and white text',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton.primary(
                label: 'Start Workout',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Start Workout'), findsOneWidget);

        final elevatedButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(
          elevatedButton.style?.backgroundColor?.resolve({}),
          AppColors.primary,
        );
        expect(
          elevatedButton.style?.foregroundColor?.resolve({}),
          AppColors.onPrimary,
        );

        await tester.tap(find.text('Start Workout'));
        await tester.pumpAndSettle();
        expect(tapped, true);
      },
    );

    testWidgets(
      'AppButton.secondary renders with soft green background and green text',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton.secondary(
                label: 'Cancel',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Cancel'), findsOneWidget);

        final elevatedButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(
          elevatedButton.style?.backgroundColor?.resolve({}),
          AppColors.secondary,
        );
        expect(
          elevatedButton.style?.foregroundColor?.resolve({}),
          AppColors.primary,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tapped, true);
      },
    );

    testWidgets(
      'AppButton.outlined renders with outlined style and green text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton.outlined(label: 'Learn More', onPressed: () {}),
            ),
          ),
        );

        expect(find.text('Learn More'), findsOneWidget);

        final elevatedButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(
          elevatedButton.style?.backgroundColor?.resolve({}),
          Colors.transparent,
        );
        expect(
          elevatedButton.style?.foregroundColor?.resolve({}),
          AppColors.primary,
        );
      },
    );
  });

  group('AppChip Redesign Tests', () {
    testWidgets(
      'Active AppChip renders with green tinted background and bold green text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: AppChip(
                label: 'Active Filter',
                isSelected: true,
                variant: AppChipVariant.selectable,
              ),
            ),
          ),
        );

        expect(find.text('Active Filter'), findsOneWidget);

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppChip),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;

        // Soft green background #CFF5D7
        expect(decoration.color, AppColors.secondary);
        expect(decoration.borderRadius, AppRadii.borderFull);
      },
    );

    testWidgets(
      'Inactive AppChip renders with light grey-green background and subtle border',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: AppChip(
                label: 'Inactive Filter',
                isSelected: false,
                variant: AppChipVariant.selectable,
              ),
            ),
          ),
        );

        expect(find.text('Inactive Filter'), findsOneWidget);

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppChip),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;

        // Inactive light grey-green background
        expect(decoration.color, AppColors.surfaceContainerLow);
        expect((decoration.border as Border).top.color, AppColors.cardBorder);
        expect(decoration.borderRadius, AppRadii.borderFull);
      },
    );
  });

  group('AppProgressBar Redesign Tests', () {
    testWidgets(
      'AppProgressBar renders with rounded ends, animated fill, and subtle glow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: AppProgressBar(value: 0.65, height: 10, showGlow: true),
            ),
          ),
        );

        expect(find.byType(AppProgressBar), findsOneWidget);

        // Settle animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final clipRRect = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byType(AppProgressBar),
            matching: find.byType(ClipRRect),
          ),
        );
        expect(clipRRect.borderRadius, BorderRadius.circular(999));
      },
    );
  });
}
