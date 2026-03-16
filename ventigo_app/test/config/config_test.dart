import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/config/env.dart';
import 'package:ventigo_app/services/avatars.dart';

void main() {
  group('Env', () {
    test('requestTimeout is 8 seconds', () {
      expect(Env.requestTimeout, const Duration(seconds: 8));
    });

    test('apiBaseUrl returns a string', () {
      // On test host, apiBaseUrl should return the production default
      expect(Env.apiBaseUrl, isNotEmpty);
    });

    test('wsBaseUrl is derived from apiBaseUrl', () {
      final ws = Env.wsBaseUrl;
      expect(ws, isNotEmpty);
      // Should start with ws:// or wss://
      expect(ws.startsWith('ws'), isTrue);
    });
  });

  group('Avatars', () {
    test('has 16 avatars', () {
      expect(avatars.length, 16);
    });

    test('each avatar has valid id', () {
      for (int i = 0; i < avatars.length; i++) {
        expect(avatars[i].id, i);
      }
    });

    test('each avatar has non-empty seed', () {
      for (final a in avatars) {
        expect(a.seed, isNotEmpty);
      }
    });

    test('each avatar has valid style', () {
      for (final a in avatars) {
        expect(
          a.style == 'adventurer' || a.style == 'adventurer-neutral',
          isTrue,
        );
      }
    });

    test('each avatar has 6-char hex bg', () {
      for (final a in avatars) {
        expect(a.bg.length, 6);
      }
    });

    test('avatarUrl produces valid DiceBear URL', () {
      final url = avatarUrl(0);
      expect(url, contains('api.dicebear.com'));
      expect(url, contains('Lily'));
    });

    test('avatarUrl handles AvatarDef input', () {
      final url = avatarUrl(avatars[3]);
      expect(url, contains(avatars[3].seed));
    });

    test('avatarUrl handles string input', () {
      final url = avatarUrl('5');
      expect(url, contains(avatars[5].seed));
    });

    test('getAvatar returns correct avatar', () {
      final a = getAvatar(7);
      expect(a.id, 7);
      expect(a.seed, 'Ruby');
    });

    test('getAvatar falls back to 0 for invalid id', () {
      final a = getAvatar(99);
      expect(a.id, 0);
    });
  });
}
