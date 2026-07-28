import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppColors holds semantic color tokens used for direct widget styling.
class AppColors {
  // --- Primary ---
  static const Color primary = Color(0xFF44664A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF7A9E7E);
  static const Color onPrimaryContainer = Color(0xFF13341C);
  static const Color primaryFixed = Color(0xFFC6ECC8);
  static const Color primaryFixedDim = Color(0xFFAAD0AD);
  static const Color onPrimaryFixed = Color(0xFF00210B);
  static const Color onPrimaryFixedVariant = Color(0xFF2D4E33);

  // --- Secondary ---
  static const Color secondary = Color(0xFF6F5959);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFF6D9D9);
  static const Color onSecondaryContainer = Color(0xFF735D5E);
  static const Color secondaryFixed = Color(0xFFF9DCDC);
  static const Color secondaryFixedDim = Color(0xFFDCC0C0);
  static const Color onSecondaryFixed = Color(0xFF271718);
  static const Color onSecondaryFixedVariant = Color(0xFF564242);

  // --- Tertiary ---
  static const Color tertiary = Color(0xFF506352);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF869A87);
  static const Color onTertiaryContainer = Color(0xFF203223);
  static const Color tertiaryFixed = Color(0xFFD3E8D2);
  static const Color tertiaryFixedDim = Color(0xFFB7CCB7);
  static const Color onTertiaryFixed = Color(0xFF0E1F12);
  static const Color onTertiaryFixedVariant = Color(0xFF394B3B);

  // --- Error ---
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // --- Surface & Background ---
  static const Color surface = Color(0xFFF8FAF8);
  static const Color onSurface = Color(0xFF191C1B);
  static const Color surfaceVariant = Color(0xFFE1E3E1);
  static const Color onSurfaceVariant = Color(0xFF424842);
  static const Color surfaceContainer = Color(0xFFECEEEC);
  static const Color surfaceContainerLow = Color(0xFFF2F4F2);
  static const Color surfaceContainerHigh = Color(0xFFE6E9E7);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E1);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD8DAD9);
  static const Color surfaceBright = Color(0xFFF8FAF8);
  static const Color surfaceTint = Color(0xFF44664A);
  static const Color background = Color(0xFFF8FAF8);
  static const Color onBackground = Color(0xFF191C1B);

  // --- Outline ---
  static const Color outline = Color(0xFF727971);
  static const Color outlineVariant = Color(0xFFC2C8BF);

  // --- Inverse ---
  static const Color inverseSurface = Color(0xFF2E3130);
  static const Color inverseOnSurface = Color(0xFFEFF1EF);
  static const Color inversePrimary = Color(0xFFAAD0AD);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF44664A),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF7A9E7E),
        onPrimaryContainer: Color(0xFF13341C),
        secondary: Color(0xFF6F5959),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFF6D9D9),
        onSecondaryContainer: Color(0xFF735D5E),
        tertiary: Color(0xFF506352),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFF869A87),
        onTertiaryContainer: Color(0xFF203223),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF93000A),
        surface: Color(0xFFF8FAF8),
        onSurface: Color(0xFF191C1B),
        surfaceContainerHighest: Color(0xFFE1E3E1),
        outline: Color(0xFF727971),
        outlineVariant: Color(0xFFC2C8BF),
        inverseSurface: Color(0xFF2E3130),
        onInverseSurface: Color(0xFFEFF1EF),
        inversePrimary: Color(0xFFAAD0AD),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAF8),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.hankenGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.64,
          height: 38 / 32,
          color: const Color(0xFF191C1B),
        ),
        headlineMedium: GoogleFonts.hankenGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 32 / 24,
          color: const Color(0xFF191C1B),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: const Color(0xFF191C1B),
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
          color: const Color(0xFF191C1B),
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
          color: const Color(0xFF424842),
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          height: 16 / 12,
          color: const Color(0xFF424842),
        ),
      ),
    );
  }

  // Custom text styles
  static TextStyle get headlineLgMobile => GoogleFonts.hankenGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
        height: 38 / 32,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.hankenGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: AppColors.onSurface,
      );

  static TextStyle get labelCaps => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        height: 16 / 12,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get dataDisplay => GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 24 / 20,
        color: AppColors.onSurface,
      );
}
