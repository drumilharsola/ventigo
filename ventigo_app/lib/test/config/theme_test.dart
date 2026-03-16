import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/config/theme.dart';
import 'package:ventigo_app/config/brand.dart';

void main() {
  // ---- AppColors ----
  group('AppColors', () {
    test('core neutrals', () {
      expect(AppColors.ink, isA<Color>());
      expect(AppColors.ink80, isA<Color>());
      expect(AppColors.charcoal, isA<Color>());
      expect(AppColors.graphite, isA<Color>());
      expect(AppColors.slate, isA<Color>());
      expect(AppColors.fog, isA<Color>());
      expect(AppColors.mist, isA<Color>());
      expect(AppColors.pale, isA<Color>());
      expect(AppColors.snow, isA<Color>());
      expect(AppColors.white, isA<Color>());
    });

    test('brand trio', () {
      expect(AppColors.peach, const Color(0xFFF4A68C));
      expect(AppColors.lavender, const Color(0xFFC4B5E3));
      expect(AppColors.amber, const Color(0xFFE8A84A));
    });

    test('poster palette', () {
      expect(AppColors.flow1, isA<Color>());
      expect(AppColors.flow2, isA<Color>());
      expect(AppColors.flow3, isA<Color>());
      expect(AppColors.flow4, isA<Color>());
      expect(AppColors.flow5, isA<Color>());
      expect(AppColors.plum, isA<Color>());
      expect(AppColors.ocean, isA<Color>());
      expect(AppColors.sunflower, isA<Color>());
      expect(AppColors.paper, isA<Color>());
    });

    test('semantic colors', () {
      expect(AppColors.accent, isA<Color>());
      expect(AppColors.accentDim, isA<Color>());
      expect(AppColors.accentGlow, isA<Color>());
      expect(AppColors.accentHover, isA<Color>());
      expect(AppColors.danger, isA<Color>());
      expect(AppColors.success, isA<Color>());
    });

    test('role colors', () {
      expect(AppColors.venterPrimary, isA<Color>());
      expect(AppColors.venterLight, isA<Color>());
      expect(AppColors.venterBubble, isA<Color>());
      expect(AppColors.venterBorder, isA<Color>());
      expect(AppColors.listenerPrimary, isA<Color>());
      expect(AppColors.listenerLight, isA<Color>());
      expect(AppColors.listenerBubble, isA<Color>());
      expect(AppColors.listenerBorder, isA<Color>());
    });

    test('surface / card colors', () {
      expect(AppColors.card, isA<Color>());
      expect(AppColors.cardLight, isA<Color>());
      expect(AppColors.border, isA<Color>());
      expect(AppColors.borderLight, isA<Color>());
      expect(AppColors.grid, isA<Color>());
    });

    test('dark mode colors', () {
      expect(AppColors.darkSurface, isA<Color>());
      expect(AppColors.darkCard, isA<Color>());
      expect(AppColors.darkBorder, isA<Color>());
    });
  });

  // ---- AppRadii ----
  group('AppRadii', () {
    test('numeric values', () {
      expect(AppRadii.sm, 10);
      expect(AppRadii.md, 18);
      expect(AppRadii.lg, 28);
      expect(AppRadii.xl, 40);
      expect(AppRadii.full, 999);
    });

    test('border radius presets', () {
      expect(AppRadii.smAll, isA<BorderRadius>());
      expect(AppRadii.mdAll, isA<BorderRadius>());
      expect(AppRadii.lgAll, isA<BorderRadius>());
      expect(AppRadii.xlAll, isA<BorderRadius>());
      expect(AppRadii.fullAll, isA<BorderRadius>());
    });
  });

  // ---- AppTypography ----
  group('AppTypography', () {
    test('hero', () {
      final s = AppTypography.hero();
      expect(s.fontSize, 80);
      expect(s.fontWeight, FontWeight.w800);
    });

    test('hero custom size', () {
      final s = AppTypography.hero(fontSize: 60);
      expect(s.fontSize, 60);
    });

    test('display', () {
      final s = AppTypography.display();
      expect(s.fontSize, 48);
      expect(s.fontWeight, FontWeight.w700);
    });

    test('display custom', () {
      final s = AppTypography.display(fontSize: 36, color: Colors.red);
      expect(s.fontSize, 36);
      expect(s.color, Colors.red);
    });

    test('title', () {
      final s = AppTypography.title();
      expect(s.fontSize, 30);
    });

    test('title custom', () {
      final s = AppTypography.title(fontSize: 24, color: Colors.blue);
      expect(s.fontSize, 24);
      expect(s.color, Colors.blue);
    });

    test('heading', () {
      final s = AppTypography.heading();
      expect(s.fontSize, 36);
    });

    test('heading custom', () {
      final s = AppTypography.heading(fontSize: 28, color: Colors.green);
      expect(s.fontSize, 28);
    });

    test('body', () {
      final s = AppTypography.body();
      expect(s.fontSize, 16);
      expect(s.fontWeight, FontWeight.w500);
    });

    test('body custom', () {
      final s = AppTypography.body(fontSize: 14, color: Colors.grey);
      expect(s.fontSize, 14);
    });

    test('label', () {
      final s = AppTypography.label();
      expect(s.fontSize, 11);
      expect(s.fontWeight, FontWeight.w800);
    });

    test('micro', () {
      final s = AppTypography.micro();
      expect(s.fontSize, 10);
    });

    test('ui defaults', () {
      final s = AppTypography.ui();
      expect(s.fontSize, 14);
      expect(s.fontWeight, FontWeight.w400);
    });

    test('ui custom', () {
      final s = AppTypography.ui(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red);
      expect(s.fontSize, 16);
      expect(s.fontWeight, FontWeight.w700);
      expect(s.color, Colors.red);
    });
  });

  // ---- warmShadow ----
  group('warmShadow', () {
    test('default params', () {
      final shadows = warmShadow();
      expect(shadows.length, 1);
      expect(shadows.first.blurRadius, 28);
      expect(shadows.first.offset, const Offset(0, 12));
    });

    test('custom params', () {
      final shadows = warmShadow(blur: 10, spread: 2, opacity: 0.5);
      expect(shadows.first.blurRadius, 10);
      expect(shadows.first.spreadRadius, 2);
    });
  });

  // ---- buildAppTheme ----
  group('buildAppTheme', () {
    test('returns ThemeData', () {
      final theme = buildAppTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.snow);
      expect(theme.useMaterial3, true);
    });

    test('has correct color scheme', () {
      final cs = buildAppTheme().colorScheme;
      expect(cs.primary, AppColors.accent);
      expect(cs.secondary, AppColors.listenerPrimary);
      expect(cs.error, AppColors.danger);
    });

    test('has text theme', () {
      final t = buildAppTheme().textTheme;
      expect(t.displayLarge, isNotNull);
      expect(t.bodyLarge, isNotNull);
      expect(t.labelSmall, isNotNull);
    });

    test('has input decoration theme', () {
      final idt = buildAppTheme().inputDecorationTheme;
      expect(idt.filled, true);
      expect(idt.fillColor, AppColors.white);
    });

    test('has button themes', () {
      final theme = buildAppTheme();
      expect(theme.elevatedButtonTheme, isNotNull);
      expect(theme.outlinedButtonTheme, isNotNull);
    });
  });

  // ---- Brand ----
  group('Brand', () {
    test('flavor', () {
      expect(Brand.flavor, isA<String>());
    });

    test('identity defaults', () {
      expect(Brand.appName, 'Ventigo');
      expect(Brand.appNamePlain, 'Ventigo');
      expect(Brand.tagline, contains('vent'));
      expect(Brand.description, contains('peer support'));
      expect(Brand.supportEmail, contains('@'));
    });

    test('logo', () {
      expect(Brand.logo, isA<BrandLogo>());
      expect(Brand.logo.text, 'ventigo');
      expect(Brand.logo.prefix, 'ven');
      expect(Brand.logo.emphasis, 'tigo');
      expect(Brand.logo.suffix, '');
    });

    test('safetyThankYou', () {
      expect(Brand.safetyThankYou, contains('Ventigo'));
    });

    test('heroCta', () {
      expect(Brand.heroCta, contains('Ventigo'));
    });

    test('heroCtaShort', () {
      expect(Brand.heroCtaShort, contains('Ventigo'));
    });

    test('onboardingTitle', () {
      expect(Brand.onboardingTitle, contains('Ventigo'));
    });
  });
}
