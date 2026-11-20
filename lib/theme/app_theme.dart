import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic design tokens for layout spacing and gaps.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Semantic border radius tokens for component corners.
abstract class AppRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderFull = BorderRadius.all(
    Radius.circular(full),
  );
}

/// Semantic animation duration tokens.
abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration microBounce = Duration(milliseconds: 200);
  static const Duration countUp = Duration(milliseconds: 1200);
  static const Duration celebrationOverlay = Duration(milliseconds: 600);
  static const Duration shimmer = Duration(milliseconds: 1500);
}

/// Semantic animation curve tokens for natural spring and smooth physics.
abstract class AppCurves {
  static const Curve spring = Curves.elasticOut;
  static const Curve smoothOut = Curves.easeOutCubic;
  static const Curve bounce = Curves.bounceOut;
  static const Curve standard = Curves.easeInOut;
}

/// Centralized Color Palette for Atlas Vitality Design System.
/// Defines high-contrast, accessible colors for Light and Dark modes.
class AppColors {
  // --- Light Mode Palette ---

  // Primary Green (#0A8F3C for buttons, active states, progress, icons)
  static const Color primary = Color(0xFF0A8F3C);
  static const Color primaryColor = Color(0xFF0A8F3C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF32D74B);
  static const Color onPrimaryContainer = Color(0xFF00390B);
  static const Color primaryFixed = Color(0xFF70FF76);
  static const Color primaryFixedDim = Color(0xFF42E355);
  static const Color onPrimaryFixed = Color(0xFF002204);
  static const Color onPrimaryFixedVariant = Color(0xFF005313);

  // Secondary Green (#CFF5D7 for backgrounds, badges, highlights)
  static const Color secondary = Color(0xFFCFF5D7);
  static const Color secondaryColor = Color(0xFFCFF5D7);
  static const Color onSecondary = Color(0xFF0A8F3C);
  static const Color secondaryContainer = Color(0xFFCFF5D7);
  static const Color onSecondaryContainer = Color(0xFF0A8F3C);
  static const Color secondaryFixed = Color(0xFFA7F5A0);
  static const Color secondaryFixedDim = Color(0xFF8BD986);
  static const Color onSecondaryFixed = Color(0xFF002204);
  static const Color onSecondaryFixedVariant = Color(0xFF005313);

  // Tertiary (Warm Terrakotta Accent)
  static const Color tertiary = Color(0xFF914944);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFA39B);
  static const Color onTertiaryContainer = Color(0xFF793632);
  static const Color tertiaryFixed = Color(0xFFFFDAD6);
  static const Color tertiaryFixedDim = Color(0xFFFFB3AD);
  static const Color onTertiaryFixed = Color(0xFF3C0807);
  static const Color onTertiaryFixedVariant = Color(0xFF74322E);

  // Status & Feedback Tokens
  static const Color success = Color(0xFF0A8F3C);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Neutral Surface Tokens (Light Mode - #F5F8F5 Background & #FFFFFF Cards)
  static const Color background = Color(
    0xFFF5F8F5,
  ); // Soft warm green-tinted background
  static const Color surface = Color(0xFFFFFFFF); // Primary cards surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFE8F0EA);
  static const Color surfaceContainerHigh = Color(0xFFDFEADE);
  static const Color surfaceContainerHighest = Color(0xFFD6E2D5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE2EDE4);
  static const Color surfaceContainer = Color(0xFFE8F0EA);

  // Text Hierarchy Tokens (High-Contrast, Readable)
  static const Color textPrimary = Color(0xFF111827); // #111827 Primary Text
  static const Color textSecondary = Color(
    0xFF4B5563,
  ); // #4B5563 Secondary Text
  static const Color mutedText = Color(0xFF6B7280); // #6B7280 Muted Text
  static const Color onSurface = Color(0xFF111827);
  static const Color onSurfaceVariant = Color(0xFF4B5563);

  // Outlines & Borders
  static const Color cardBorder = Color(
    0xFFD7EEDB,
  ); // #D7EEDB Subtle Green Card Border
  static const Color outline = Color(0xFFCAD5CB);
  static const Color outlineVariant = Color(0xFFD7EEDB);

  // Activity Ring Specific Colors
  static const Color ringStreak = Color(0xFF32D74B);
  static const Color ringCalories = Color(0xFFFF3B30);
  static const Color ringProtein = Color(0xFF007AFF);

  // Inverse Tokens
  static const Color inverseSurface = Color(0xFF2E3034);
  static const Color inverseOnSurface = Color(0xFFF0F0F5);
  static const Color inversePrimary = Color(0xFF42E355);

  // --- Dark Mode Palette ---
  static const Color darkBackground = Color(0xFF101213);
  static const Color darkSurface = Color(0xFF1B1E20);
  static const Color darkSurfaceElevated = Color(0xFF25292C);
  static const Color darkCardBorder = Color(0xFF2E3338);
  static const Color darkPrimary = Color(0xFF32D74B);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFCCCCCC);
  static const Color darkMutedText = Color(0xFF9EA3AC);
}

/// Semantic shadow tokens for card elevations, glows, and badges.
abstract class AppShadows {
  static const BoxShadow softCard = BoxShadow(
    color: Color(0x0D0A8F3C),
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  static const BoxShadow cardHover = BoxShadow(
    color: Color(0x1F0A8F3C),
    blurRadius: 20,
    spreadRadius: 1,
    offset: Offset(0, 4),
  );

  static const BoxShadow primaryGlow = BoxShadow(
    color: Color(0x330A8F3C),
    blurRadius: 16,
    spreadRadius: 1,
    offset: Offset(0, 4),
  );

  static final BoxShadow ambientGlow = BoxShadow(
    color: AppColors.primary.withValues(alpha: 0.25),
    blurRadius: 24,
    spreadRadius: 4,
    offset: const Offset(0, 4),
  );

  static final BoxShadow goldGlow = BoxShadow(
    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
    blurRadius: 28,
    spreadRadius: 6,
    offset: const Offset(0, 4),
  );

  static final BoxShadow rankBadge = BoxShadow(
    color: const Color(0xFFFFB300).withValues(alpha: 0.3),
    blurRadius: 20,
    spreadRadius: 2,
  );
}

/// Centralized border definitions across the app.
abstract class AppBorders {
  static const Border cardBorderLight = Border.fromBorderSide(
    BorderSide(color: AppColors.cardBorder, width: 1),
  );

  static const Border cardBorderDark = Border.fromBorderSide(
    BorderSide(color: AppColors.darkCardBorder, width: 1),
  );

  static const Border activeBorder = Border.fromBorderSide(
    BorderSide(color: AppColors.primary, width: 1.5),
  );
}

/// Semantic gradient tokens for premium surfaces and visual identity.
abstract class AppGradients {
  static const LinearGradient vitalityGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A8F3C), Color(0xFF32D74B)],
  );

  static const LinearGradient secondarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCFF5D7), Color(0xFFEAF9EE)],
  );

  static const LinearGradient goldRank = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE082), Color(0xFFFFD700), Color(0xFFFF8F00)],
  );

  static const LinearGradient emeraldGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
  );

  static const LinearGradient neonXp = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
  );

  static final LinearGradient darkGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF1E2228).withValues(alpha: 0.9),
      const Color(0xFF14171C).withValues(alpha: 0.75),
    ],
  );

  static final LinearGradient lightGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.95),
      const Color(0xFFF0FDF4).withValues(alpha: 0.85),
    ],
  );

  static const RadialGradient trophyGold = RadialGradient(
    colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
  );
}

/// Centralized card decorations and presets.
abstract class AppCardStyles {
  /// Primary white card decoration with #D7EEDB border and soft shadow.
  static BoxDecoration primaryCard(
    BuildContext context, {
    double borderRadius = AppRadii.xl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
        width: 1,
      ),
      boxShadow: [
        isDark
            ? BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            : AppShadows.softCard,
      ],
    );
  }

  /// Highlight card decoration with soft secondary green (#CFF5D7).
  static BoxDecoration highlightCard(
    BuildContext context, {
    double borderRadius = AppRadii.xl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? AppColors.primary.withValues(alpha: 0.15)
          : AppColors.secondary.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? AppColors.darkPrimary.withValues(alpha: 0.4)
            : AppColors.primary.withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [if (!isDark) AppShadows.softCard],
    );
  }
}

/// Centralized button style presets.
abstract class AppButtonStyles {
  /// Primary filled button style with #0A8F3C background and white text.
  static ButtonStyle primary({double borderRadius = AppRadii.md}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  /// Secondary soft button style with #CFF5D7 background and #0A8F3C text.
  static ButtonStyle secondary({double borderRadius = AppRadii.md}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.secondary,
      foregroundColor: AppColors.onSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  /// Outlined button style with subtle border.
  static ButtonStyle outlined({double borderRadius = AppRadii.md}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.cardBorder, width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

/// Centralized text input style presets.
abstract class AppInputStyles {
  static InputDecoration standard({
    required BuildContext context,
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
      hintText: hintText,
      labelText: labelText,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.darkPrimary : AppColors.primary,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}

/// Centralized Typography Hierarchy for Atlas Vitality Design System.
///
/// Hierarchy:
/// - Headers Large: 32px Bold
/// - Headers Section: 24px Bold
/// - Cards: 18-20px Semibold
/// - Body: 15-16px Regular
/// - Labels: 12-14px Uppercase (Bold / Semibold with wide letter spacing)
abstract class AppTypography {
  /// Headers Large (32px Bold) - Screen main titles, hero headings
  static TextStyle get headerLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.32,
    height: 40 / 32,
    color: AppColors.textPrimary,
  );

  /// Headers Section (24px Bold) - Major category headings, section titles
  static TextStyle get headerSection => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 30 / 24,
    color: AppColors.textPrimary,
  );

  /// Cards Title Large (20px Semibold) - Primary card and modal titles
  static TextStyle get cardTitleLg => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
    color: AppColors.textPrimary,
  );

  /// Cards Title Standard (18px Semibold) - Standard card titles, widget headers
  static TextStyle get cardTitle => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  /// Body Large (16px Regular) - Key lead paragraphs, prominent body text
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.textPrimary,
  );

  /// Body Standard (15px Regular) - Standard content, instructions, descriptions
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.textPrimary,
  );

  /// Body Small (14px Regular) - Secondary descriptions, helper text, subtitles
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  /// Labels Large Uppercase (14px Bold Uppercase) - Primary tags, badges, high-contrast labels
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 18 / 14,
    color: AppColors.textSecondary,
  );

  /// Labels Medium Uppercase (12px Bold Uppercase) - Micro-caps, status badges, overlines
  static TextStyle get labelCaps => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 16 / 12,
    color: AppColors.textSecondary,
  );
}

/// Extension on BuildContext for effortless dynamic Light/Dark theme adaptability.
extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground =>
      isDarkMode ? AppColors.darkBackground : AppColors.background;
  Color get appSurface =>
      isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get appSurfaceElevated =>
      isDarkMode ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated;
  Color get appSurfaceContainerLow =>
      isDarkMode ? const Color(0xFF171A1C) : AppColors.surfaceContainerLow;
  Color get appSurfaceVariant =>
      isDarkMode ? AppColors.darkSurfaceElevated : AppColors.surfaceVariant;
  Color get appCardBg => isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get appCardBorder =>
      isDarkMode ? AppColors.darkCardBorder : AppColors.cardBorder;

  Color get appPrimary =>
      isDarkMode ? AppColors.darkPrimary : AppColors.primary;
  Color get appSecondary =>
      isDarkMode ? const Color(0xFF216C28) : AppColors.secondary;
  Color get appTextPrimary =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get appTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get appTextMuted =>
      isDarkMode ? AppColors.darkMutedText : AppColors.mutedText;
  Color get appOutlineVariant =>
      isDarkMode ? const Color(0xFF3F454B) : AppColors.outlineVariant;

  LinearGradient get appBackgroundGradient => isDarkMode
      ? const LinearGradient(colors: [Color(0xFF101213), Color(0xFF101213)])
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF2EC), Color(0xFFF5F8F5), Color(0xFFEFF5F0)],
          stops: [0.0, 0.5, 1.0],
        );

  BoxShadow get appCardShadow => isDarkMode
      ? BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      : AppShadows.softCard;

  // --- Typography Context Helpers ---
  TextStyle get headerLarge =>
      AppTypography.headerLarge.copyWith(color: appTextPrimary);
  TextStyle get headerSection =>
      AppTypography.headerSection.copyWith(color: appTextPrimary);
  TextStyle get cardTitleLg =>
      AppTypography.cardTitleLg.copyWith(color: appTextPrimary);
  TextStyle get cardTitle =>
      AppTypography.cardTitle.copyWith(color: appTextPrimary);
  TextStyle get bodyLarge =>
      AppTypography.bodyLarge.copyWith(color: appTextPrimary);
  TextStyle get bodyText => AppTypography.body.copyWith(color: appTextPrimary);
  TextStyle get bodySmall =>
      AppTypography.bodySmall.copyWith(color: appTextSecondary);
  TextStyle get labelLarge =>
      AppTypography.labelLarge.copyWith(color: appTextSecondary);
  TextStyle get labelCaps =>
      AppTypography.labelCaps.copyWith(color: appTextSecondary);
}

/// Central Theme Definition providing MaterialApp Light and Dark themes.
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
        onSecondary: AppColors.onSecondary,
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
      textTheme: _textTheme(
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.mutedText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: AppColors.mutedText),
        helperStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
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
        primary: AppColors.darkPrimary,
        onPrimary: Color(0xFF00390B),
        primaryContainer: Color(0xFF006E1C),
        onPrimaryContainer: Colors.white,
        secondary: Color(0xFFA4F39D),
        onSecondary: Color(0xFF00390B),
        secondaryContainer: Color(0xFF216C28),
        onSecondaryContainer: Colors.white,
        tertiary: AppColors.tertiaryContainer,
        onTertiary: Color(0xFF410002),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: Color(0xFF2E3338),
        outline: Color(0xFFA3ACA1),
        outlineVariant: Color(0xFF3F454B),
        inverseSurface: Color(0xFFFFFFFF),
        onInverseSurface: Color(0xFF1A1C1F),
        inversePrimary: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _textTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
        AppColors.darkMutedText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        labelStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: AppColors.darkMutedText),
        helperStyle: const TextStyle(color: AppColors.darkTextSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.darkCardBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.darkPrimary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.darkPrimary,
        linearTrackColor: const Color(0xFF25292C),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  static TextTheme _textTheme(Color mainText, Color subText, Color muted) {
    return TextTheme(
      // Headers Large (32px Bold)
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
        height: 40 / 32,
        color: mainText,
      ),
      // Headers Section (24px Bold)
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 30 / 24,
        color: mainText,
      ),
      // Cards Title Large (20px Semibold)
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        color: mainText,
      ),
      // Cards Title Standard (18px Semibold)
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: mainText,
      ),
      // Sub-titles / Compact titles (16px Semibold)
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        color: mainText,
      ),
      // Body Large (16px Regular)
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: mainText,
      ),
      // Body Standard (15px Regular)
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: mainText,
      ),
      // Body Small (14px Regular)
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: subText,
      ),
      // Labels Large Uppercase (14px Bold Uppercase)
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 18 / 14,
        color: subText,
      ),
      // Labels Medium Uppercase (12px Bold Uppercase)
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 16 / 12,
        color: subText,
      ),
      // Labels Small (12px Bold Uppercase)
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 16 / 12,
        color: subText,
      ),
    );
  }

  // --- Static TextStyle Tokens for Component Usage ---
  static TextStyle get displayMetrics => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.96,
    height: 56 / 48,
    color: AppColors.textPrimary,
  );

  /// Headers Large (32px Bold)
  static TextStyle get headlineLg => AppTypography.headerLarge;

  static TextStyle get headlineLgMobile => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    color: AppColors.textPrimary,
  );

  /// Headers Section (24px Bold)
  static TextStyle get headlineMd => AppTypography.headerSection;

  /// Cards Title Large (20px Semibold)
  static TextStyle get headlineSm => AppTypography.cardTitleLg;

  /// Cards Title Standard (18px Semibold)
  static TextStyle get titleLg => AppTypography.cardTitle;

  /// Sub-titles (16px Semibold)
  static TextStyle get titleMd => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );

  /// Body Large (16px Regular)
  static TextStyle get bodyLg => AppTypography.bodyLarge;

  /// Body Standard (15px Regular)
  static TextStyle get bodyMd => AppTypography.body;

  /// Body Small (14px Regular)
  static TextStyle get bodySm => AppTypography.bodySmall;

  /// Labels Large (14px Bold Uppercase)
  static TextStyle get labelLarge => AppTypography.labelLarge;

  /// Labels Medium (12px Bold Uppercase)
  static TextStyle get labelCaps => AppTypography.labelCaps;

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    color: AppColors.mutedText,
  );

  static TextStyle get dataDisplay => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 24 / 20,
    color: AppColors.textPrimary,
  );
}
