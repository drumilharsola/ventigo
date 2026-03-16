import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/config/brand.dart';
import 'package:ventigo_app/config/env.dart';

void main() {
  group('Brand', () {
    test('flavor defaults to ventigo', () {
      expect(Brand.flavor, 'ventigo');
    });

    test('appName defaults to Ventigo', () {
      expect(Brand.appName, 'Ventigo');
    });

    test('appNamePlain defaults to Ventigo', () {
      expect(Brand.appNamePlain, 'Ventigo');
    });

    test('tagline contains vent', () {
      expect(Brand.tagline, contains('vent'));
    });

    test('description is non-empty', () {
      expect(Brand.description, isNotEmpty);
    });

    test('supportEmail is valid email format', () {
      expect(Brand.supportEmail, contains('@'));
    });

    test('logo has non-empty parts', () {
      expect(Brand.logo.text, isNotEmpty);
      expect(Brand.logo.prefix, isNotEmpty);
      expect(Brand.logo.emphasis, isNotEmpty);
    });

    test('logo text is ventigo', () {
      expect(Brand.logo.text, 'ventigo');
    });

    test('safetyThankYou contains app name', () {
      expect(Brand.safetyThankYou, contains('Ventigo'));
    });

    test('heroCta contains app name', () {
      expect(Brand.heroCta, contains('Ventigo'));
    });

    test('heroCtaShort contains app name', () {
      expect(Brand.heroCtaShort, contains('Ventigo'));
    });

    test('onboardingTitle contains app name', () {
      expect(Brand.onboardingTitle, contains('Ventigo'));
    });
  });

  group('Env', () {
    test('requestTimeout is 8 seconds', () {
      expect(Env.requestTimeout, const Duration(seconds: 8));
    });

    test('boardWsUrl includes token', () {
      final url = Env.boardWsUrl('mytoken');
      expect(url, contains('mytoken'));
      expect(url, contains('/board/ws'));
    });

    test('boardWsUrl encodes special chars in token', () {
      final url = Env.boardWsUrl('tok en&123');
      expect(url, contains('tok%20en%26123'));
    });

    test('chatWsUrl includes token and roomId', () {
      final url = Env.chatWsUrl('mytoken', 'room123');
      expect(url, contains('mytoken'));
      expect(url, contains('room123'));
      expect(url, contains('/chat/ws'));
    });

    test('chatWsUrl encodes special chars', () {
      final url = Env.chatWsUrl('tok&en', 'room id');
      expect(url, contains('tok%26en'));
      expect(url, contains('room%20id'));
    });

    test('tenantId defaults to empty string', () {
      expect(Env.tenantId, '');
    });

    test('sentryDsn defaults to empty string', () {
      expect(Env.sentryDsn, '');
    });

    test('onesignalAppId defaults to empty string', () {
      expect(Env.onesignalAppId, '');
    });

    test('posthogApiKey defaults to empty string', () {
      expect(Env.posthogApiKey, '');
    });

    test('posthogHost has default value', () {
      expect(Env.posthogHost, isNotEmpty);
    });

    test('environment defaults to production', () {
      expect(Env.environment, 'production');
    });
  });
}
