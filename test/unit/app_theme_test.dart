import 'package:atlas/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('google_fonts') ||
          details.exception.toString().contains('font')) {
        return; // Ignore font asset fetching warnings in headless tests
      }
      FlutterError.presentError(details);
    };
  });

  group('AppColors - Light Mode Palette Verification', () {
    test('Background is soft warm green-tinted #F5F8F5', () {
      expect(AppColors.background, const Color(0xFFF5F8F5));
    });

    test('Primary cards surface is #FFFFFF and border is #D7EEDB', () {
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.cardBorder, const Color(0xFFD7EEDB));
      expect(AppColors.outlineVariant, const Color(0xFFD7EEDB));
    });

    test(
      'Primary Green is #0A8F3C for buttons, active states, progress, icons',
      () {
        expect(AppColors.primary, const Color(0xFF0A8F3C));
        expect(AppColors.primaryColor, const Color(0xFF0A8F3C));
        expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
      },
    );

    test('Secondary Green is #CFF5D7 for backgrounds, badges, highlights', () {
      expect(AppColors.secondary, const Color(0xFFCFF5D7));
      expect(AppColors.secondaryColor, const Color(0xFFCFF5D7));
      expect(AppColors.secondaryContainer, const Color(0xFFCFF5D7));
      expect(AppColors.onSecondary, const Color(0xFF0A8F3C));
    });

    test(
      'Text hierarchy uses high-contrast colors (#111827, #4B5563, #6B7280)',
      () {
        expect(AppColors.textPrimary, const Color(0xFF111827));
        expect(AppColors.textSecondary, const Color(0xFF4B5563));
        expect(AppColors.mutedText, const Color(0xFF6B7280));
        expect(AppColors.onSurface, const Color(0xFF111827));
        expect(AppColors.onSurfaceVariant, const Color(0xFF4B5563));
      },
    );

    test('Dark Mode tokens are preserved and consistent', () {
      expect(AppColors.darkBackground, const Color(0xFF101213));
      expect(AppColors.darkSurface, const Color(0xFF1B1E20));
      expect(AppColors.darkCardBorder, const Color(0xFF2E3338));
      expect(AppColors.darkPrimary, const Color(0xFF32D74B));
      expect(AppColors.darkTextPrimary, const Color(0xFFFFFFFF));
      expect(AppColors.darkTextSecondary, const Color(0xFFCCCCCC));
      expect(AppColors.darkMutedText, const Color(0xFF9EA3AC));
    });
  });

  group('Spacing & Radii Tokens', () {
    test('Spacing constants scale properly', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
      expect(AppSpacing.xxxl, 32.0);
    });

    test('Radii constants and BorderRadius objects are valid', () {
      expect(AppRadii.sm, 8.0);
      expect(AppRadii.md, 12.0);
      expect(AppRadii.lg, 16.0);
      expect(AppRadii.xl, 20.0);
      expect(AppRadii.xxl, 24.0);
      expect(AppRadii.full, 999.0);

      expect(AppRadii.borderSm.topLeft.x, 8.0);
      expect(AppRadii.borderMd.topLeft.x, 12.0);
      expect(AppRadii.borderLg.topLeft.x, 16.0);
      expect(AppRadii.borderXl.topLeft.x, 20.0);
      expect(AppRadii.borderFull.topLeft.x, 999.0);
    });
  });

  group('Shadows & Borders', () {
    test('Shadow tokens have valid offsets and colors', () {
      expect(AppShadows.softCard.blurRadius, 16);
      expect(AppShadows.cardHover.blurRadius, 20);
      expect(AppShadows.primaryGlow.blurRadius, 16);
      expect(AppShadows.goldGlow.blurRadius, 28);
    });

    test('Border tokens match palette rules', () {
      expect(AppBorders.cardBorderLight.top.color, AppColors.cardBorder);
      expect(AppBorders.cardBorderDark.top.color, AppColors.darkCardBorder);
      expect(AppBorders.activeBorder.top.color, AppColors.primary);
    });
  });

  group('Gradients', () {
    test('Vitality green gradient contains primary green', () {
      expect(AppGradients.vitalityGreen.colors.first, AppColors.primary);
      expect(AppGradients.secondarySoft.colors.first, AppColors.secondary);
      expect(AppGradients.goldRank.colors.length, 3);
    });
  });

  group('Typography Hierarchy (Phase 5)', () {
    test('Headers Large: 32px bold', () {
      expect(AppTypography.headerLarge.fontSize, 32);
      expect(AppTypography.headerLarge.fontWeight, FontWeight.w700);
      expect(AppTheme.headlineLg.fontSize, 32);
      expect(AppTheme.headlineLg.fontWeight, FontWeight.w700);
      expect(AppTheme.headlineLg.color, AppColors.textPrimary);
    });

    test('Section Headers: 24px bold', () {
      expect(AppTypography.headerSection.fontSize, 24);
      expect(AppTypography.headerSection.fontWeight, FontWeight.w700);
      expect(AppTheme.headlineMd.fontSize, 24);
      expect(AppTheme.headlineMd.fontWeight, FontWeight.w700);
      expect(AppTheme.headlineMd.color, AppColors.textPrimary);
    });

    test('Cards Titles: 18-20px semibold', () {
      expect(AppTypography.cardTitleLg.fontSize, 20);
      expect(AppTypography.cardTitleLg.fontWeight, FontWeight.w600);
      expect(AppTypography.cardTitle.fontSize, 18);
      expect(AppTypography.cardTitle.fontWeight, FontWeight.w600);

      expect(AppTheme.headlineSm.fontSize, 20);
      expect(AppTheme.headlineSm.fontWeight, FontWeight.w600);
      expect(AppTheme.titleLg.fontSize, 18);
      expect(AppTheme.titleLg.fontWeight, FontWeight.w600);
    });

    test('Body: 15-16px', () {
      expect(AppTypography.bodyLarge.fontSize, 16);
      expect(AppTypography.bodyLarge.fontWeight, FontWeight.w400);
      expect(AppTypography.body.fontSize, 15);
      expect(AppTypography.body.fontWeight, FontWeight.w400);

      expect(AppTheme.bodyLg.fontSize, 16);
      expect(AppTheme.bodyMd.fontSize, 15);
      expect(AppTheme.bodySm.fontSize, 14);
    });

    test('Labels: 12-14px uppercase with wide letter spacing', () {
      expect(AppTypography.labelLarge.fontSize, 14);
      expect(AppTypography.labelLarge.fontWeight, FontWeight.w700);
      expect(AppTypography.labelLarge.letterSpacing, 1.0);

      expect(AppTypography.labelCaps.fontSize, 12);
      expect(AppTypography.labelCaps.fontWeight, FontWeight.w700);
      expect(AppTypography.labelCaps.letterSpacing, 0.8);

      expect(AppTheme.labelLarge.fontSize, 14);
      expect(AppTheme.labelCaps.fontSize, 12);
    });
  });

  group('ThemeData Definitions', () {
    test('lightTheme contains correct colorScheme and scaffold background', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    });

    test('darkTheme contains correct dark background and colorScheme', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(theme.colorScheme.surface, AppColors.darkSurface);
      expect(theme.colorScheme.onSurface, AppColors.darkTextPrimary);
    });
  });

  group('AppThemeContext Extension', () {
    testWidgets('provides correct Light Mode colors from BuildContext', (
      tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedContext.isDarkMode, false);
      expect(capturedContext.appBackground, const Color(0xFFF5F8F5));
      expect(capturedContext.appCardBg, const Color(0xFFFFFFFF));
      expect(capturedContext.appCardBorder, const Color(0xFFD7EEDB));
      expect(capturedContext.appPrimary, const Color(0xFF0A8F3C));
      expect(capturedContext.appSecondary, const Color(0xFFCFF5D7));
      expect(capturedContext.appTextPrimary, const Color(0xFF111827));
      expect(capturedContext.appTextSecondary, const Color(0xFF4B5563));
      expect(capturedContext.appTextMuted, const Color(0xFF6B7280));
    });

    testWidgets('provides correct Dark Mode colors from BuildContext', (
      tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedContext.isDarkMode, true);
      expect(capturedContext.appBackground, const Color(0xFF101213));
      expect(capturedContext.appCardBg, const Color(0xFF1B1E20));
      expect(capturedContext.appCardBorder, const Color(0xFF2E3338));
      expect(capturedContext.appPrimary, const Color(0xFF32D74B));
      expect(capturedContext.appTextPrimary, const Color(0xFFFFFFFF));
      expect(capturedContext.appTextSecondary, const Color(0xFFCCCCCC));
      expect(capturedContext.appTextMuted, const Color(0xFF9EA3AC));
    });
  });

  group('Card, Button & Input Style Helpers', () {
    testWidgets('AppCardStyles generates correct decoration', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final decoration = AppCardStyles.primaryCard(capturedContext);
      expect(decoration.color, AppColors.surface);
      expect((decoration.border as Border).top.color, AppColors.cardBorder);

      final highlightDec = AppCardStyles.highlightCard(capturedContext);
      expect(highlightDec.color, isNotNull);
    });

    test('AppButtonStyles generates proper ButtonStyles', () {
      final primaryStyle = AppButtonStyles.primary();
      expect(primaryStyle.backgroundColor?.resolve({}), AppColors.primary);
      expect(primaryStyle.foregroundColor?.resolve({}), AppColors.onPrimary);

      final secondaryStyle = AppButtonStyles.secondary();
      expect(secondaryStyle.backgroundColor?.resolve({}), AppColors.secondary);
      expect(
        secondaryStyle.foregroundColor?.resolve({}),
        AppColors.onSecondary,
      );
    });
  });
}
