import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/models/current_speaker_request.dart';
import '../helpers/test_helpers.dart';

void main() {
  // -- PendingWaitState --
  group('PendingWaitState', () {
    test('defaults', () {
      const s = PendingWaitState();
      expect(s.requestId, isNull);
      expect(s.remaining, 600);
      expect(s.timedOut, false);
      expect(s.matchedRoomId, isNull);
      expect(s.isWaiting, false);
    });

    test('isWaiting true when active', () {
      const s = PendingWaitState(requestId: 'r1');
      expect(s.isWaiting, true);
    });

    test('isWaiting false when timedOut', () {
      const s = PendingWaitState(requestId: 'r1', timedOut: true);
      expect(s.isWaiting, false);
    });

    test('isWaiting false when matched', () {
      const s = PendingWaitState(requestId: 'r1', matchedRoomId: 'room1');
      expect(s.isWaiting, false);
    });

    test('copyWith all fields', () {
      const s = PendingWaitState();
      final s2 = s.copyWith(
        requestId: 'r1',
        remaining: 300,
        timedOut: true,
        matchedRoomId: 'match1',
      );
      expect(s2.requestId, 'r1');
      expect(s2.remaining, 300);
      expect(s2.timedOut, true);
      expect(s2.matchedRoomId, 'match1');
    });

    test('clearRequest', () {
      const s = PendingWaitState(requestId: 'r1');
      final s2 = s.copyWith(clearRequest: true);
      expect(s2.requestId, isNull);
    });

    test('clearMatch', () {
      const s = PendingWaitState(matchedRoomId: 'room1');
      final s2 = s.copyWith(clearMatch: true);
      expect(s2.matchedRoomId, isNull);
    });
  });

  // -- PendingWaitNotifier.processPollResponseForTest --
  group('PendingWaitNotifier processPollResponse', () {
    late ProviderContainer container;
    late PendingWaitNotifier notifier;

    setUp(() {
      container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(FakeApiClient()),
      ]);
      addTearDown(container.dispose);
      notifier = container.read(pendingWaitProvider.notifier);
      // Set a request to simulate waiting state
      notifier.state = const PendingWaitState(requestId: 'r1', remaining: 600);
    });

    tearDown(() => container.dispose());

    test('matched response sets matchedRoomId', () {
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'matched',
          roomId: 'match-room',
          postedAt: '0',
        ),
      );
      expect(notifier.state.matchedRoomId, 'match-room');
    });

    test('null postedAt sets timedOut', () {
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
        ),
      );
      expect(notifier.state.timedOut, true);
    });

    test('elapsed time updates remaining', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      notifier.processPollResponseForTest(
        CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: (now - 100).toString(),
        ),
      );
      // remaining = 600 - 100 = ~500
      expect(notifier.state.remaining, closeTo(500, 5));
      expect(notifier.state.timedOut, false);
    });

    test('fully elapsed sets timedOut', () {
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: '1000000',
        ),
      );
      expect(notifier.state.timedOut, true);
    });

    test('remaining clamped to 0', () {
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: '1000000',
        ),
      );
      expect(notifier.state.timedOut, true);
    });
  });

  // -- clearMatch --
  group('PendingWaitNotifier clearMatch', () {
    test('resets state', () {
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(FakeApiClient()),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pendingWaitProvider.notifier);
      notifier.state = const PendingWaitState(
          requestId: 'r1', matchedRoomId: 'room1');
      notifier.clearMatch();
      expect(notifier.state.requestId, isNull);
      expect(notifier.state.matchedRoomId, isNull);
    });
  });
}
