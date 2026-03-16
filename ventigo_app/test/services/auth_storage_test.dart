import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('FakeAuthStorage (exercises AuthStorage interface)', () {
    late FakeAuthStorage storage;

    setUp(() {
      storage = FakeAuthStorage();
    });

    test('readToken returns null initially', () async {
      expect(await storage.readToken(), isNull);
    });

    test('readSessionId returns null initially', () async {
      expect(await storage.readSessionId(), isNull);
    });

    test('readUsername returns null initially', () async {
      expect(await storage.readUsername(), isNull);
    });

    test('readAvatarId returns null initially', () async {
      expect(await storage.readAvatarId(), isNull);
    });

    test('readEmailVerified returns null initially', () async {
      expect(await storage.readEmailVerified(), isNull);
    });

    test('saveAuth persists token and sessionId', () async {
      await storage.saveAuth('tok123', 'sid456');
      expect(await storage.readToken(), 'tok123');
      expect(await storage.readSessionId(), 'sid456');
    });

    test('saveProfile persists username and avatarId', () async {
      await storage.saveProfile('alice', 5);
      expect(await storage.readUsername(), 'alice');
      expect(await storage.readAvatarId(), 5);
    });

    test('saveAvatarId updates avatarId', () async {
      await storage.saveProfile('alice', 1);
      await storage.saveAvatarId(9);
      expect(await storage.readAvatarId(), 9);
    });

    test('saveEmailVerified true', () async {
      await storage.saveEmailVerified(true);
      expect(await storage.readEmailVerified(), true);
    });

    test('saveEmailVerified false', () async {
      await storage.saveEmailVerified(false);
      expect(await storage.readEmailVerified(), false);
    });

    test('clear removes all data', () async {
      await storage.saveAuth('tok', 'sid');
      await storage.saveProfile('alice', 1);
      await storage.saveEmailVerified(true);
      await storage.clear();
      expect(await storage.readToken(), isNull);
      expect(await storage.readSessionId(), isNull);
      expect(await storage.readUsername(), isNull);
      expect(await storage.readAvatarId(), isNull);
      expect(await storage.readEmailVerified(), isNull);
    });
  });
}
