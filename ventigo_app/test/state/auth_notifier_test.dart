import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('AuthNotifier', () {
    late FakeAuthStorage storage;
    late AuthNotifier notifier;

    setUp(() {
      storage = FakeAuthStorage();
      notifier = AuthNotifier(storage);
    });

    test('initial state', () {
      expect(notifier.state.token, isNull);
      expect(notifier.state.hasHydrated, false);
      expect(notifier.state.isLoggedIn, false);
    });

    test('hydrate reads from storage', () async {
      await storage.saveAuth('tok1', 'sid1');
      await storage.saveProfile('user1', 5);
      await storage.saveEmailVerified(true);

      await notifier.hydrate();

      expect(notifier.state.token, 'tok1');
      expect(notifier.state.sessionId, 'sid1');
      expect(notifier.state.username, 'user1');
      expect(notifier.state.avatarId, 5);
      expect(notifier.state.emailVerified, true);
      expect(notifier.state.hasHydrated, true);
      expect(notifier.state.isLoggedIn, true);
      expect(notifier.state.hasProfile, true);
    });

    test('hydrate with empty storage', () async {
      await notifier.hydrate();

      expect(notifier.state.token, isNull);
      expect(notifier.state.hasHydrated, true);
    });

    test('setAuth updates state and persists', () async {
      await notifier.setAuth('newtoken', 'newsession');

      expect(notifier.state.token, 'newtoken');
      expect(notifier.state.sessionId, 'newsession');
      expect(await storage.readToken(), 'newtoken');
      expect(await storage.readSessionId(), 'newsession');
    });

    test('setProfile updates state and persists', () async {
      await notifier.setProfile('myuser', 3);

      expect(notifier.state.username, 'myuser');
      expect(notifier.state.avatarId, 3);
      expect(await storage.readUsername(), 'myuser');
      expect(await storage.readAvatarId(), 3);
    });

    test('setAvatarId updates state and persists', () async {
      await notifier.setAvatarId(7);

      expect(notifier.state.avatarId, 7);
      expect(await storage.readAvatarId(), 7);
    });

    test('setEmailVerified updates state and persists', () async {
      await notifier.setEmailVerified(true);

      expect(notifier.state.emailVerified, true);
      expect(await storage.readEmailVerified(), true);
    });

    test('clear resets state but keeps hasHydrated', () async {
      await notifier.setAuth('tok', 'sid');
      await notifier.setProfile('user', 1);
      await notifier.clear();

      expect(notifier.state.token, isNull);
      expect(notifier.state.sessionId, isNull);
      expect(notifier.state.username, isNull);
      expect(notifier.state.avatarId, isNull);
      expect(notifier.state.hasHydrated, true);
      expect(notifier.state.isLoggedIn, false);
      expect(notifier.state.hasProfile, false);
      // Storage should be empty too
      expect(await storage.readToken(), isNull);
    });

    test('refreshEmailVerified does nothing when already verified', () async {
      await notifier.setAuth('tok', 'sid');
      await notifier.setEmailVerified(true);
      // Should return immediately without calling API
      await notifier.refreshEmailVerified(FakeApiClient());
      expect(notifier.state.emailVerified, true);
    });

    test('refreshEmailVerified does nothing when no token', () async {
      // No token set
      await notifier.refreshEmailVerified(FakeApiClient());
      expect(notifier.state.emailVerified, isNull);
    });

    test('refreshEmailVerified updates from server', () async {
      await notifier.setAuth('tok', 'sid');
      // emailVerified is null (not yet verified locally)
      await notifier.refreshEmailVerified(FakeApiClient());
      // FakeApiClient.getMe returns emailVerified=true
      expect(notifier.state.emailVerified, true);
    });
  });

  group('FakeAuthStorage', () {
    late FakeAuthStorage storage;
    setUp(() => storage = FakeAuthStorage());

    test('readToken returns null when empty', () async {
      expect(await storage.readToken(), isNull);
    });

    test('saveAuth and read', () async {
      await storage.saveAuth('t', 's');
      expect(await storage.readToken(), 't');
      expect(await storage.readSessionId(), 's');
    });

    test('saveProfile and read', () async {
      await storage.saveProfile('u', 5);
      expect(await storage.readUsername(), 'u');
      expect(await storage.readAvatarId(), 5);
    });

    test('saveAvatarId', () async {
      await storage.saveAvatarId(9);
      expect(await storage.readAvatarId(), 9);
    });

    test('saveEmailVerified and read', () async {
      await storage.saveEmailVerified(false);
      expect(await storage.readEmailVerified(), false);
      await storage.saveEmailVerified(true);
      expect(await storage.readEmailVerified(), true);
    });

    test('clear removes everything', () async {
      await storage.saveAuth('t', 's');
      await storage.saveProfile('u', 1);
      await storage.clear();
      expect(await storage.readToken(), isNull);
      expect(await storage.readUsername(), isNull);
    });
  });
}
