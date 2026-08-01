import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic design tokens for spacing in padding and layout gaps.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

/// Semantic border radius tokens for component corners.
abstract class AppRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderFull = BorderRadius.all(Radius.circular(full));
}

/// Semantic animation duration tokens.
abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Semantic design tokens for the Aizawl Gym Vitality Design System.
class AppColors {
  // Brand Primary (Vitality Green)
  static const Color primary = Color(0xFF006E1C);
  static const Color primaryColor = Color(0xFF006E1C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF32D74B);
  static const Color onPrimaryContainer = Color(0xFF005814);
  static const Color primaryFixed = Color(0xFF70FF76);
  static const Color primaryFixedDim = Color(0xFF42E355);
  static const Color onPrimaryFixed = Color(0xFF002204);
  static const Color onPrimaryFixedVariant = Color(0xFF005313);

  // Secondary & Accents
  static const Color secondary = Color(0xFF216C28);
  static const Color secondaryColor = Color(0xFF216C28);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFA4F39D);
  static const Color onSecondaryContainer = Color(0xFF26712C);
  static const Color secondaryFixed = Color(0xFFA7F5A0);
  static const Color secondaryFixedDim = Color(0xFF8BD986);
  static const Color onSecondaryFixed = Color(0xFF002204);
  static const Color onSecondaryFixedVariant = Color(0xFF005313);

  // Tertiary (Warm Terrakotta)
  static const Color tertiary = Color(0xFF914944);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFA39B);
  static const Color onTertiaryContainer = Color(0xFF793632);
  static const Color tertiaryFixed = Color(0xFFFFDAD6);
  static const Color tertiaryFixedDim = Color(0xFFFFB3AD);
  static const Color onTertiaryFixed = Color(0xFF3C0807);
  static const Color onTertiaryFixedVariant = Color(0xFF74322E);

  // Status & Feedback Tokens
  static const Color success = Color(0xFF32D74B);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Neutral Surface Tokens (Default Light)
  static const Color background = Color(0xFFF9F9FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFEDEDF2);
  static const Color surfaceContainerLow = Color(0xFFF3F3F8);
  static const Color surfaceContainerHigh = Color(0xFFE8E8ED);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE2E2E7);
  static const Color surfaceContainer = Color(0xFFEDEDF2);

  // Text Hierarchy Tokens (Default Light)
  static const Color textPrimary = Color(0xFF1A1C1F);
  static const Color textSecondary = Color(0xFF3D4A3A);
  static const Color onSurface = Color(0xFF1A1C1F);
  static const Color onSurfaceVariant = Color(0xFF3D4A3A);

  // Activity Ring Specific Colors
  static const Color ringStreak = Color(0xFF32D74B);
  static const Color ringCalories = Color(0xFFFF3B30);
  static const Color ringProtein = Color(0xFF007AFF);

  // Outlines & Dividers
  static const Color outline = Color(0xFF6D7B68);
  static const Color outlineVariant = Color(0xFFBBCBB5);

  // Inverse Tokens
  static const Color inverseSurface = Color(0xFF2E3034);
  static const Color inverseOnSurface = Color(0xFFF0F0F5);
  static const Color inversePrimary = Color(0xFF42E355);
}

/// Extension on BuildContext for effortless dynamic Light/Dark mode theme adaptability.
extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground => isDarkMode ? const Color(0xFF101213) : const Color(0xFFF8FCF8);
  Color get appSurface => isDarkMode ? const Color(0xFF1B1E20) : AppColors.surface;
  Color get appSurfaceElevated => isDarkMode ? const Color(0xFF25292C) : AppColors.surfaceElevated;
  Color get appSurfaceContainerLow => isDarkMode ? const Color(0xFF171A1C) : AppColors.surfaceContainerLow;
  Color get appTextPrimary => isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
  Color get appTextSecondary => isDarkMode ? const Color(0xFFCCCCCC) : AppColors.textSecondary;
  Color get appPrimary => isDarkMode ? const Color(0xFF32D74B) : AppColors.primary;
  Color get appOutlineVariant => isDarkMode ? const Color(0xFF3F454B) : AppColors.outlineVariant;
  Color get appCardBg => isDarkMode
      ? const Color(0xFF1B1E20).withValues(alpha: 0.85)
      : const Color(0xFFFFFFFF);

  LinearGradient get appBackgroundGradient => isDarkMode
      ? const LinearGradient(
          colors: [Color(0xFF101213), Color(0xFF101213)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF8EE), // Top Left
            Color(0xFFF8FCF8), // Center
            Color(0xFFF2FBF4), // Bottom Right
          ],
          stops: [0.0, 0.5, 1.0],
        );

  BoxShadow get appCardShadow => isDarkMode
      ? BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 4),
        )
      : BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 6),
        );

  Color get appCardBorder => isDarkMode
      ? const Color(0xFF2E3338).withValues(alpha: 0.3)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.65);
}

class AppTheme {
  // Light Theme Definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
        helperStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryContainer,
        onPrimary: Color(0xFF00390B),
        primaryContainer: AppColors.primary,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.secondaryContainer,
        onSecondary: Color(0xFF00390B),
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: Colors.white,
        tertiary: AppColors.tertiaryContainer,
        onTertiary: Color(0xFF410002),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        surface: Color(0xFF1B1E20),
        onSurface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0xFF2E3338),
        outline: Color(0xFFA3ACA1),
        outlineVariant: Color(0xFF3F454B),
        inverseSurface: Color(0xFFFFFFFF),
        onInverseSurface: Color(0xFF1A1C1F),
        inversePrimary: AppColors.primary,
      ),
      scaffoldBackgroundColor: const Color(0xFF101213),
      textTheme: _textTheme(const Color(0xFFFFFFFF), const Color(0xFFCCCCCC)),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF9EA3AC)),
        helperStyle: const TextStyle(color: Color(0xFFCCCCCC)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF3F454B), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color mainText, Color subText) {
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
        height: 40 / 32,
        color: mainText,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 30 / 24,
        color: mainText,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 24 / 17,
        color: mainText,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 20 / 15,
        color: mainText,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 20 / 15,
        color: subText,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 16 / 12,
        color: subText,
      ),
    );
  }

  // Static TextStyle getters
  static TextStyle get displayMetrics => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.96,
        height: 56 / 48,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLg => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
        height: 40 / 32,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 30 / 24,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 24 / 17,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 20 / 15,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 20 / 15,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get labelCaps => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 16 / 12,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get dataDisplay => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 24 / 20,
        color: AppColors.onSurface,
      );
}
