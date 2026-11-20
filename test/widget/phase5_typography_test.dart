import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/widgets/common/section_header.dart';
import 'package:atlas/widgets/common/app_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('google_fonts') ||
          details.exception.toString().contains('font')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: Scaffold(body: child),
    );
  }

  group('Phase 5 Typography Upgrade - Token Hierarchy Verification', () {
    test('Headers Large: 32px bold token', () {
      expect(AppTypography.headerLarge.fontSize, 32);
      expect(AppTypography.headerLarge.fontWeight, FontWeight.w700);
      expect(AppTypography.headerLarge.height, 40 / 32);
      expect(AppTheme.headlineLg.fontSize, 32);
      expect(AppTheme.headlineLg.fontWeight, FontWeight.w700);
    });

    test('Headers Section: 24px bold token', () {
      expect(AppTypography.headerSection.fontSize, 24);
      expect(AppTypography.headerSection.fontWeight, FontWeight.w700);
      expect(AppTypography.headerSection.height, 30 / 24);
      expect(AppTheme.headlineMd.fontSize, 24);
      expect(AppTheme.headlineMd.fontWeight, FontWeight.w700);
    });

    test('Cards: 18-20px semibold tokens', () {
      // 20px card title large
      expect(AppTypography.cardTitleLg.fontSize, 20);
      expect(AppTypography.cardTitleLg.fontWeight, FontWeight.w600);
      expect(AppTheme.headlineSm.fontSize, 20);
      expect(AppTheme.headlineSm.fontWeight, FontWeight.w600);

      // 18px card title standard
      expect(AppTypography.cardTitle.fontSize, 18);
      expect(AppTypography.cardTitle.fontWeight, FontWeight.w600);
      expect(AppTheme.titleLg.fontSize, 18);
      expect(AppTheme.titleLg.fontWeight, FontWeight.w600);
    });

    test('Body: 15-16px tokens', () {
      // 16px body large
      expect(AppTypography.bodyLarge.fontSize, 16);
      expect(AppTypography.bodyLarge.fontWeight, FontWeight.w400);
      expect(AppTheme.bodyLg.fontSize, 16);
      expect(AppTheme.bodyLg.fontWeight, FontWeight.w400);

      // 15px body standard
      expect(AppTypography.body.fontSize, 15);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
      expect(AppTheme.bodyMd.fontSize, 15);
      expect(AppTheme.bodyMd.fontWeight, FontWeight.w400);
    });

    test('Labels: 12-14px uppercase with wide letter spacing', () {
      // 14px uppercase label
      expect(AppTypography.labelLarge.fontSize, 14);
      expect(AppTypography.labelLarge.fontWeight, FontWeight.w700);
      expect(AppTypography.labelLarge.letterSpacing, 1.0);
      expect(AppTheme.labelLarge.fontSize, 14);

      // 12px uppercase label
      expect(AppTypography.labelCaps.fontSize, 12);
      expect(AppTypography.labelCaps.fontWeight, FontWeight.w700);
      expect(AppTypography.labelCaps.letterSpacing, 0.8);
      expect(AppTheme.labelCaps.fontSize, 12);
    });
  });

  group('Phase 5 Typography Component & Extension Tests', () {
    testWidgets('SectionHeader renders with 24px bold headlineMd', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const SectionHeader(
            title: 'TODAY PROTOCOL',
            subtitle: 'Hypertrophy Block A',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TODAY PROTOCOL'), findsOneWidget);
      expect(find.text('Hypertrophy Block A'), findsOneWidget);

      final titleText = tester.widget<Text>(find.text('TODAY PROTOCOL'));
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.fontWeight, FontWeight.w700);
    });

    testWidgets(
      'AppThemeContext extension exposes consistent typography helpers',
      (tester) async {
        late TextStyle capturedHeaderLarge;
        late TextStyle capturedHeaderSection;
        late TextStyle capturedCardTitle;
        late TextStyle capturedBody;
        late TextStyle capturedLabelCaps;

        await tester.pumpWidget(
          buildTestApp(
            Builder(
              builder: (context) {
                capturedHeaderLarge = context.headerLarge;
                capturedHeaderSection = context.headerSection;
                capturedCardTitle = context.cardTitle;
                capturedBody = context.bodyText;
                capturedLabelCaps = context.labelCaps;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();

        expect(capturedHeaderLarge.fontSize, 32);
        expect(capturedHeaderLarge.fontWeight, FontWeight.w700);

        expect(capturedHeaderSection.fontSize, 24);
        expect(capturedHeaderSection.fontWeight, FontWeight.w700);

        expect(capturedCardTitle.fontSize, 18);
        expect(capturedCardTitle.fontWeight, FontWeight.w600);

        expect(capturedBody.fontSize, 15);
        expect(capturedBody.fontWeight, FontWeight.w400);

        expect(capturedLabelCaps.fontSize, 12);
        expect(capturedLabelCaps.fontWeight, FontWeight.w700);
      },
    );

    testWidgets('AppCard renders child text smoothly within hierarchy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card Title', style: AppTypography.cardTitle),
                Text('Body Text', style: AppTypography.body),
                Text('TAG LABEL', style: AppTypography.labelCaps),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Card Title'), findsOneWidget);
      expect(find.text('Body Text'), findsOneWidget);
      expect(find.text('TAG LABEL'), findsOneWidget);

      final cardTitle = tester.widget<Text>(find.text('Card Title'));
      expect(cardTitle.style?.fontSize, 18);
      expect(cardTitle.style?.fontWeight, FontWeight.w600);

      final body = tester.widget<Text>(find.text('Body Text'));
      expect(body.style?.fontSize, 15);
      expect(body.style?.fontWeight, FontWeight.w400);

      final label = tester.widget<Text>(find.text('TAG LABEL'));
      expect(label.style?.fontSize, 12);
      expect(label.style?.fontWeight, FontWeight.w700);
      expect(label.style?.letterSpacing, 0.8);
    });
  });
}
