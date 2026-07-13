import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale ported from the web app's "operator density" utilities
/// (text-display .. text-caption). 1 CSS px ~= 1 dp.
TextTheme _textTheme(Color foreground, Color muted) => TextTheme(
      // text-display: 24px / 700
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.48,
        color: foreground,
      ),
      // text-h1: 20px / 600
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: foreground,
      ),
      // text-h2: 17px / 600
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      // text-h3: 15px / 500
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: foreground,
      ),
      // text-body: 14px / 400
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: foreground,
      ),
      // text-small: 12px / 400
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      // text-caption: 11px / 500 / uppercase (apply uppercase at call site)
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.55,
        color: muted,
      ),
    );

/// Minimum touch target — Project DNA non-negotiable #3.
const double kMinTapTarget = 44;

ThemeData _base({
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color surface,
  required Color mutedForeground,
  required Color border,
  required Color primary,
  required Color primaryForeground,
  required Color secondary,
  required Color secondaryForeground,
  required Color destructive,
}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: primaryForeground,
    secondary: secondary,
    onSecondary: secondaryForeground,
    error: destructive,
    onError: Colors.white,
    surface: surface,
    onSurface: foreground,
    outline: border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    dividerColor: border,
    textTheme: _textTheme(foreground, mutedForeground),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // rounded-xl — cards
        side: BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: primaryForeground,
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // rounded-lg — buttons
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
  );
}

abstract final class AppTheme {
  static ThemeData get light => _base(
        brightness: Brightness.light,
        background: AppColorsLight.background,
        foreground: AppColorsLight.foreground,
        surface: AppColorsLight.surface,
        mutedForeground: AppColorsLight.mutedForeground,
        border: AppColorsLight.border,
        primary: AppColorsLight.primary,
        primaryForeground: AppColorsLight.primaryForeground,
        secondary: AppColorsLight.secondary,
        secondaryForeground: AppColorsLight.secondaryForeground,
        destructive: AppColorsLight.destructive,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        background: AppColorsDark.background,
        foreground: AppColorsDark.foreground,
        surface: AppColorsDark.surface,
        mutedForeground: AppColorsDark.mutedForeground,
        border: AppColorsDark.border,
        primary: AppColorsDark.primary,
        primaryForeground: AppColorsDark.primaryForeground,
        secondary: AppColorsDark.secondary,
        secondaryForeground: AppColorsDark.secondaryForeground,
        destructive: AppColorsDark.destructive,
      );
}
