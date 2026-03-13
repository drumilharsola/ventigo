import 'package:flutter/material.dart';

/// Hex-string → Color helper for compile-time brand overrides.
Color _hex(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// Warm, peach/lavender/amber colour tokens for the Unburden brand.
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

  // ── Core neutrals (warm) ──
  static final Color ink       = _envInk.isNotEmpty ? _hex(_envInk) : const Color(0xFF3B3335);
  static const Color ink80     = Color(0xCC3B3335);
  static final Color charcoal  = _envCharcoal.isNotEmpty ? _hex(_envCharcoal) : const Color(0xFF4D4448);
  static const Color graphite  = Color(0xFF635860);
  static final Color slate     = _envSlate.isNotEmpty ? _hex(_envSlate) : const Color(0xFF8A7F85);
  static final Color fog       = _envFog.isNotEmpty ? _hex(_envFog) : const Color(0xFFB5ABAF);
  static const Color mist      = Color(0xFFD9D0D3);
  static const Color pale      = Color(0xFFF0E8EA);
  static const Color snow      = Color(0xFFFFF8F0);
  static const Color white     = Color(0xFFFFFFFF);

  // ── Brand trio ──
  static const Color peach     = Color(0xFFF4A68C);  // venter / warmth
  static const Color lavender  = Color(0xFFC4B5E3);  // listener / calm
  static const Color amber     = Color(0xFFE8A84A);  // connection / bridge

  // ── Poster palette (warm) ──
  static const Color flow1 = Color(0xFFFFF0E8);
  static const Color flow2 = Color(0xFFFFE0D0);
  static const Color flow3 = Color(0xFFF4A68C);
  static const Color flow4 = Color(0xFFE88F72);
  static const Color flow5 = Color(0xFFD47858);
  static const Color plum = Color(0xFFC4B5E3);
  static const Color ocean = Color(0xFFE8A84A);
  static const Color sunflower = Color(0xFFF0C060);
  static const Color paper = Color(0xFFFFF4E8);

  // ── Semantic ──
  static final Color accent     = _envAccent.isNotEmpty ? _hex(_envAccent) : const Color(0xFFF4A68C);
  static const Color accentDim  = Color(0x21F4A68C);
  static const Color accentGlow = Color(0x47F4A68C);
  static final Color accentHover = _envAccentHover.isNotEmpty ? _hex(_envAccentHover) : const Color(0xFFE88F72);
  static final Color danger     = _envDanger.isNotEmpty ? _hex(_envDanger) : const Color(0xFFE88888);
  static final Color success    = _envSuccess.isNotEmpty ? _hex(_envSuccess) : const Color(0xFF7ECAA0);

  // ── Role colours ──
  static const Color venterPrimary = Color(0xFFF4A68C);
  static const Color venterLight   = Color(0xFFFFF0E8);
  static const Color venterBubble  = Color(0xFFFFF8F4);
  static const Color venterBorder  = Color(0x40F4A68C);

  static const Color listenerPrimary = Color(0xFFC4B5E3);
  static const Color listenerLight   = Color(0xFFF0ECF8);
  static const Color listenerBubble  = Color(0xFFF8F5FC);
  static const Color listenerBorder  = Color(0x40C4B5E3);

  // ── Surface / card ──
  static const Color card       = Color(0xFFFFFCF6);
  static const Color cardLight  = Color(0xFFFFF6EA);
  static const Color border     = Color(0x173B3335);
  static const Color borderLight = Color(0x0F3B3335);
  static const Color grid = Color(0x10FFFFFF);

  // ── Dark-mode surface overrides ──
  static const Color darkSurface  = Color(0xFF1F1A1C);
  static const Color darkCard     = Color(0xFF2D2628);
  static const Color darkBorder   = Color(0x24FFFFFF);
}

/// Border-radius tokens.
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

/// Typography helpers powered by bundled local fonts.
class AppTypography {
  AppTypography._();

  static const _fontDisplay = String.fromEnvironment('BRAND_FONT_DISPLAY', defaultValue: 'Comfortaa');
  static const _fontUI = String.fromEnvironment('BRAND_FONT_UI', defaultValue: 'Inter');

  static TextStyle get _display => const TextStyle(fontFamily: _fontDisplay);
  static TextStyle get _ui => const TextStyle(fontFamily: _fontUI);

  // ------ Display scale ------

  static TextStyle hero({double fontSize = 80}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, height: 0.9, letterSpacing: -2.2, color: AppColors.ink);

  static TextStyle display({double fontSize = 48, Color? color}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -1.2, color: color ?? AppColors.ink);

  static TextStyle title({double fontSize = 30, Color? color}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -0.9, color: color ?? AppColors.ink);

  static TextStyle heading({double fontSize = 36, Color? color}) =>
      _display.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -1.0, color: color ?? AppColors.ink);

  // ------ UI scale ------

  static TextStyle body({double fontSize = 15, Color? color}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: FontWeight.w500, height: 1.55, letterSpacing: -0.15, color: color ?? AppColors.slate);

  static TextStyle label({double fontSize = 11, Color? color}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: color ?? AppColors.slate);

  static TextStyle ui({double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) =>
      _ui.copyWith(fontSize: fontSize, fontWeight: fontWeight, letterSpacing: -0.1, color: color ?? AppColors.graphite);
}

List<BoxShadow> warmShadow({double blur = 28, double spread = 0, double opacity = 0.12}) {
  return [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 12),
    ),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.snow,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.listenerPrimary,
      surface: AppColors.card,
      error: AppColors.danger,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.ink,
      onError: AppColors.white,
    ),
    useMaterial3: true,
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
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      hintStyle: AppTypography.ui(fontSize: 14, color: AppColors.fog),
      border: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: BorderSide(color: AppColors.ink, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        elevation: 0,
        textStyle: AppTypography.ui(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: BorderSide(color: AppColors.ink, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.snow,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.slate,
      indicatorColor: AppColors.accent,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll, side: const BorderSide(color: AppColors.border)),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
  );
}
