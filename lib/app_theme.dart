import 'package:flutter/material.dart';

/// TravelMate colour palette.
///
/// These values are translated from the supplied TravelMate HTML/CSS design
/// system:
/// navy: #0B2340 / #0F3057 / #163B63
/// teal: #0E8C82 / #14A69B / #E1F5F2
/// coral: #FF6B4A / #F0553A / #FFE7E0
/// background: #F5F8FA / #ECF1F4
class TravelMateColors {
  TravelMateColors._();

  static const navy900 = Color(0xFF0B2340);
  static const navy800 = Color(0xFF0F3057);
  static const navy700 = Color(0xFF163B63);

  static const teal600 = Color(0xFF0E8C82);
  static const teal500 = Color(0xFF14A69B);
  static const teal100 = Color(0xFFE1F5F2);

  static const coral500 = Color(0xFFFF6B4A);
  static const coral600 = Color(0xFFF0553A);
  static const coral100 = Color(0xFFFFE7E0);

  static const background = Color(0xFFF5F8FA);
  static const backgroundAlt = Color(0xFFECF1F4);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDEE6EB);

  static const textPrimary = Color(0xFF14202B);
  static const textSecondary = Color(0xFF56697A);
  static const textMuted = Color(0xFF8A9BA8);

  static const success = Color(0xFF2E9E5B);
  static const successBackground = Color(0xFFE5F5EC);
  static const warning = Color(0xFFC9822A);
  static const warningBackground = Color(0xFFFCF0DE);
}

/// Centralised TravelMate theme.
///
/// The HTML design uses Inter and a compact card/button system. The Flutter
/// implementation uses the same visual hierarchy and colour values while
/// relying on platform-safe Material components.
class TravelMateTheme {
  TravelMateTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TravelMateColors.background,
      colorScheme: const ColorScheme.light(
        primary: TravelMateColors.navy800,
        onPrimary: Colors.white,
        secondary: TravelMateColors.teal600,
        onSecondary: Colors.white,
        surface: TravelMateColors.surface,
        onSurface: TravelMateColors.textPrimary,
        error: TravelMateColors.coral600,
        onError: Colors.white,
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: TravelMateColors.textPrimary,
      displayColor: TravelMateColors.textPrimary,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: TravelMateColors.textSecondary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: TravelMateColors.textSecondary,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: TravelMateColors.textMuted,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: TravelMateColors.surface,
        foregroundColor: TravelMateColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: TravelMateColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: TravelMateColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: TravelMateColors.border,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TravelMateColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: TravelMateColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: TravelMateColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TravelMateColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TravelMateColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: TravelMateColors.teal600,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TravelMateColors.coral600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: TravelMateColors.coral600,
            width: 1.5,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TravelMateColors.navy800,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TravelMateColors.teal600,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TravelMateColors.navy800,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          side: const BorderSide(color: TravelMateColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TravelMateColors.teal600,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: TravelMateColors.textSecondary,
          minimumSize: const Size(42, 42),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TravelMateColors.teal600;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: TravelMateColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: TravelMateColors.backgroundAlt,
        selectedColor: TravelMateColors.teal100,
        side: const BorderSide(color: TravelMateColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: TravelMateColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: TravelMateColors.navy900,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TravelMateColors.teal600,
        linearTrackColor: TravelMateColors.backgroundAlt,
      ),
    );
  }
}


/// Compatibility aliases used by the feature screens.
class AppTheme {
  AppTheme._();

  static const bg = TravelMateColors.background;
  static const bgAlt = TravelMateColors.backgroundAlt;
  static const border = TravelMateColors.border;
  static const coral = TravelMateColors.coral500;
  static const coral100 = TravelMateColors.coral100;
  static const navy900 = TravelMateColors.navy900;
  static const navy800 = TravelMateColors.navy800;
  static const navy700 = TravelMateColors.navy700;
  static const teal = TravelMateColors.teal600;
  static const teal100 = TravelMateColors.teal100;
  static const textPrimary = TravelMateColors.textPrimary;
  static const textSecondary = TravelMateColors.textSecondary;
  static const textMuted = TravelMateColors.textMuted;
  static const success = TravelMateColors.success;
  static const warning = TravelMateColors.warning;
}
