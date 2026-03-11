import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hex-string → Color helper for compile-time brand overrides.
Color _hex(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// All brand colour tokens.
///
/// Default values match ``brand.config.json``.  Override at build time via
/// ``--dart-define=BRAND_COLOR_ACCENT=#FF0000`` etc.
class AppColors {
  AppColors._();

  static const _envInk       = String.fromEnvironment('BRAND_COLOR_INK');
  static const _envCharcoal  = String.fromEnvironment('BRAND_COLOR_CHARCOAL');
  static const _envSlate     = String.fromEnvironment('BRAND_COLOR_SLATE');
  static const _envFog       = String.fromEnvironment('BRAND_COLOR_FOG');
  static const _envAccent    = String.fromEnvironment('BRAND_COLOR_ACCENT');
  static const _envAccentHover = String.fromEnvironment('BRAND_COLOR_ACCENT_HOVER');
  static const _envDanger    = String.fromEnvironment('BRAND_COLOR_DANGER');
  static const _envSuccess   = String.fromEnvironment('BRAND_COLOR_SUCCESS');

  // Neutrals
  static final Color ink       = _envInk.isNotEmpty ? _hex(_envInk) : const Color(0xFF0B2F2A);
  static const Color ink80     = Color(0xCC0B2F2A);
  static final Color charcoal  = _envCharcoal.isNotEmpty ? _hex(_envCharcoal) : const Color(0xFF1D3D35);
  static const Color graphite  = Color(0xFF2D4C44);
  static final Color slate     = _envSlate.isNotEmpty ? _hex(_envSlate) : const Color(0xFF5C7A71);
  static final Color fog       = _envFog.isNotEmpty ? _hex(_envFog) : const Color(0xFF8CA99F);
  static const Color mist      = Color(0xFFBFD2C6);
  static const Color pale      = Color(0xFFE6F2EC);
  static const Color snow      = Color(0xFFF4F8F6);
  static const Color white     = Color(0xFFFFFFFF);

  // Flow palette
  static const Color flow1 = Color(0xFFDFF6F1);
  static const Color flow2 = Color(0xFFD2F1E4);
  static const Color flow3 = Color(0xFF82C9B5);
  static const Color flow4 = Color(0xFF6BBFA4);
  static const Color flow5 = Color(0xFF47A78C);

  // Semantic
  static final Color accent     = _envAccent.isNotEmpty ? _hex(_envAccent) : const Color(0xFF62B49C);
  static const Color accentDim  = Color(0x1F62B49C); // 12% opacity
  static const Color accentGlow = Color(0x4762B49C); // 28% opacity
  static final Color accentHover = _envAccentHover.isNotEmpty ? _hex(_envAccentHover) : const Color(0xFF7BD1B2);
  static final Color danger     = _envDanger.isNotEmpty ? _hex(_envDanger) : const Color(0xFFE88888);
  static final Color success    = _envSuccess.isNotEmpty ? _hex(_envSuccess) : const Color(0xFF7ECAA0);

  // Surface / card
  static const Color card = Color(0x0DFFFFFF); // 5%
  static const Color cardLight = Color(0xDBFFFFFF); // 86%
  static const Color border = Color(0x17FFFFFF); // 9%
  static const Color borderLight = Color(0x140F0C1A); // 8%
}

/// Border-radius tokens from CSS custom properties.
class AppRadii {
  AppRadii._();

  static const double sm = 10;
  static const double md = 18;
  static const double lg = 28;
  static const double xl = 40;
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Typography helpers — font families overridable via --dart-define.
class AppTypography {
  AppTypography._();

  static const _fontDisplay = String.fromEnvironment('BRAND_FONT_DISPLAY', defaultValue: 'Comfortaa');
  static const _fontUI = String.fromEnvironment('BRAND_FONT_UI', defaultValue: 'Inter');

  static TextStyle get _display => GoogleFonts.getFont(_fontDisplay);
  static TextStyle get _ui => GoogleFonts.getFont(_fontUI);

  // ------ Display scale ------

  /// .t-hero  — clamp(56,9vw,120) weight 900
  static TextStyle hero({double fontSize = 80}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w900, height: 0.95, color: AppColors.white);

  /// .t-display — clamp(36,5vw,64) weight 700
  static TextStyle display({double fontSize = 48, Color color = AppColors.white}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.1, color: color);

  /// .t-title — clamp(24,3vw,36) weight 700
  static TextStyle title({double fontSize = 30, Color color = AppColors.white}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5, color: color);

  /// Heading on forms (36px, w700).
  static TextStyle heading({double fontSize = 36}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6, color: AppColors.white);

  // ------ UI scale ------

  /// .t-body — 15px weight 300
  static TextStyle body({double fontSize = 15, Color color = AppColors.fog}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: FontWeight.w300, height: 1.65, color: color);

  /// .t-label — 11px weight 600 uppercase tracking
  static TextStyle label({double fontSize = 11, Color color = AppColors.slate}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: color);

  /// General ui text.
  static TextStyle ui({double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color color = AppColors.white}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

/// Build the app-wide dark ThemeData.
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentHover,
      surface: AppColors.charcoal,
      error: AppColors.danger,
      onPrimary: AppColors.ink,
      onSecondary: AppColors.ink,
      onSurface: AppColors.white,
      onError: AppColors.white,
    ),
    textTheme: TextTheme(
      displayLarge: AppTypography.hero(),
      displayMedium: AppTypography.display(),
      headlineMedium: AppTypography.title(),
      bodyLarge: AppTypography.body(),
      bodyMedium: AppTypography.ui(),
      labelSmall: AppTypography.label(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.accentGlow, width: 1.5),
      ),
      hintStyle: const TextStyle(color: Color(0x33FFFFFF)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.fog,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
      ),
    ),
  );
}
