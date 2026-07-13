import 'package:flutter/material.dart';

/// Design tokens ported from `berdikari-web/app/assets/css/tailwind.css`.
/// Keep both palettes in sync with the web app — it is the reference.
abstract final class AppColorsLight {
  static const background = Color(0xFFF3F4F6); // hsl(220 14% 96%)
  static const foreground = Color(0xFF141B24); // hsl(215 28% 11%)
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F2F4); // hsl(220 14% 95%)
  static const mutedForeground = Color(0xFF657386); // hsl(215 14% 46%)
  static const border = Color(0xFFDBDFE6); // hsl(215 18% 88%)

  static const primary = Color(0xFF19766D); // hsl(174 65% 28%) — deep teal
  static const primaryForeground = Color(0xFFFFFFFF);

  static const secondary = Color(0xFFEBEDF0); // hsl(215 14% 93%)
  static const secondaryForeground = Color(0xFF253141); // hsl(215 28% 20%)

  static const accent = Color(0xFFE4F6F4); // hsl(174 50% 93%)
  static const accentForeground = Color(0xFF15655D); // hsl(174 65% 24%)

  static const destructive = Color(0xFFDC2828); // hsl(0 72% 51%)
  static const success = Color(0xFF1B743C); // hsl(142 62% 28%)
  static const warning = Color(0xFFD17205); // hsl(32 95% 42%)

  static const ring = Color(0xFF1F9388); // hsl(174 65% 35%)
}

abstract final class AppColorsDark {
  static const background = Color(0xFF11161D); // hsl(215 28% 9%)
  static const foreground = Color(0xFFEDF2F7); // hsl(210 40% 95%)
  static const surface = Color(0xFF161D27); // hsl(215 28% 12%)
  static const surfaceMuted = Color(0xFF1D2734); // hsl(215 28% 16%)
  static const mutedForeground = Color(0xFF77879C); // hsl(215 16% 54%)
  static const border = Color(0xFF2E3642); // hsl(215 18% 22%)

  static const primary = Color(0xFF33A398); // hsl(174 52% 42%)
  static const primaryForeground = Color(0xFFFFFFFF);

  static const secondary = Color(0xFF212C3B); // hsl(215 28% 18%)
  static const secondaryForeground = Color(0xFFE2EBF3); // hsl(210 40% 92%)

  static const accent = Color(0xFF1E3E3B); // hsl(174 35% 18%)
  static const accentForeground = Color(0xFF83D8CF); // hsl(174 52% 68%)

  static const destructive = Color(0xFFB42D2D); // hsl(0 60% 44%)
  static const success = Color(0xFF2C8C4F); // hsl(142 52% 36%)
  static const warning = Color(0xFFD37C17); // hsl(32 80% 46%)

  static const ring = Color(0xFF33A398);
}

/// Exposes the `success`/`warning` tokens (not part of Flutter's
/// [ColorScheme]) the same way `colorScheme.error` exposes `destructive`.
extension AppColorSchemeExtras on ColorScheme {
  Color get success =>
      brightness == Brightness.dark ? AppColorsDark.success : AppColorsLight.success;
  Color get warning =>
      brightness == Brightness.dark ? AppColorsDark.warning : AppColorsLight.warning;
}
