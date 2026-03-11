/// Brand configuration — single source of truth for white-label parameters.
///
/// Values come from compile-time `--dart-define` overrides or fall back to
/// the defaults matching ``brand.config.json`` in the project root.
///
/// Build with a specific flavor:
///   flutter build apk --flavor unburden --dart-define=BRAND=unburden
///   flutter build apk --flavor clientdemo --dart-define=BRAND=clientdemo
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class BrandLogo {
  const BrandLogo({
    required this.text,
    required this.prefix,
    required this.emphasis,
    required this.suffix,
  });

  final String text;
  final String prefix;
  final String emphasis;
  final String suffix;
}

/// Active brand flavor name (e.g. "unburden", "clientdemo").
const String _brandFlavor = String.fromEnvironment(
  'BRAND',
  defaultValue: 'unburden',
);

class Brand {
  const Brand._();

  /// The active flavor name.
  static const String flavor = _brandFlavor;

  // ── Identity ────────────────────────────────────────────────────────────

  static const String appName = String.fromEnvironment(
    'BRAND_APP_NAME',
    defaultValue: 'UNBurDEN',
  );

  static const String appNamePlain = String.fromEnvironment(
    'BRAND_APP_NAME_PLAIN',
    defaultValue: 'Unburden',
  );

  static const String tagline = String.fromEnvironment(
    'BRAND_TAGLINE',
    defaultValue: 'a safe place to be heard',
  );

  static const String description = String.fromEnvironment(
    'BRAND_DESCRIPTION',
    defaultValue: 'Anonymous peer support in 15-minute sessions.',
  );

  static const String supportEmail = String.fromEnvironment(
    'BRAND_SUPPORT_EMAIL',
    defaultValue: 'support@unburden.app',
  );

  // ── Logo ────────────────────────────────────────────────────────────────

  static const logo = BrandLogo(
    text: String.fromEnvironment('BRAND_LOGO_TEXT', defaultValue: 'Unburden'),
    prefix: String.fromEnvironment('BRAND_LOGO_PREFIX', defaultValue: 'Unb'),
    emphasis: String.fromEnvironment('BRAND_LOGO_EMPHASIS', defaultValue: 'ur'),
    suffix: String.fromEnvironment('BRAND_LOGO_SUFFIX', defaultValue: 'den'),
  );

  // ── Copy ────────────────────────────────────────────────────────────────

  static String get safetyThankYou =>
      'Thank you for helping keep $appName safe.';

  static String get heroCta => "Let's ${appNamePlain} →";

  static String get heroCtaShort => "Let's ${appNamePlain}";

  static String get onboardingTitle => 'How $appNamePlain works';

  // ── Runtime asset loading (optional) ────────────────────────────────────

  /// Load the per-flavor brand.json from assets at runtime.
  /// Useful for reading additional config values not covered by dart-define.
  static Future<Map<String, dynamic>> loadFlavorConfig() async {
    final raw = await rootBundle.loadString(
      'assets/brands/$flavor/brand.json',
    );
    return json.decode(raw) as Map<String, dynamic>;
  }
}
