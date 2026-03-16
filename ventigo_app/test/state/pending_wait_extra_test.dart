import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/models/current_speaker_request.dart';
import '../helpers/test_helpers.dart';

/// FakeApiClient that tracks cancelSpeak calls.
class _TrackingApi extends FakeApiClient {
  int cancelCalls = 0;

  @override
  Future<void> cancelSpeak(String token) async {
    cancelCalls++;
  }
}

void main() {
  group('PendingWaitNotifier cancel', () {
    test('cancel calls cancelSpeak on api', () async {
      final api = _TrackingApi();
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pendingWaitProvider.notifier);

      // Set state to simulate active waiting
      notifier.state =
          const PendingWaitState(requestId: 'r1', remaining: 500);
      notifier.cancel();

      // After cancel, api.cancelSpeak should have been called
      // Give async call a moment
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.cancelCalls, 1);
      expect(notifier.state.requestId, isNull);
      expect(notifier.state.isWaiting, false);
    });

    test('cancel with no token does not call api', () async {
      final api = _TrackingApi();
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: const AuthState())),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pendingWaitProvider.notifier);
      notifier.state =
          const PendingWaitState(requestId: 'r1', remaining: 500);
      notifier.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.cancelCalls, 0);
    });

    test('cancel with no requestId does not call api', () async {
      final api = _TrackingApi();
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pendingWaitProvider.notifier);
      // No requestId set
      notifier.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.cancelCalls, 0);
    });
  });

  group('PendingWaitNotifier processPollResponse edge cases', () {
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
      notifier.state =
          const PendingWaitState(requestId: 'r1', remaining: 600);
    });

    test('matched status without roomId still sets matchedRoomId', () {
      // When status is matched but roomId is null, the null is set
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'matched',
          roomId: null,
          postedAt: '0',
        ),
      );
      // matchedRoomId is null since roomId was null, so copyWith won't override
      // the previous null — state is unchanged for matchedRoomId
      expect(notifier.state.matchedRoomId, isNull);
    });

    test('very recent postedAt yields full remaining', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      notifier.processPollResponseForTest(
        CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: now.toString(),
        ),
      );
      expect(notifier.state.remaining, closeTo(600, 5));
      expect(notifier.state.timedOut, false);
    });

    test('partial elapsed time updates remaining correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      notifier.processPollResponseForTest(
        CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: (now - 300).toString(),
        ),
      );
      expect(notifier.state.remaining, closeTo(300, 5));
      expect(notifier.state.timedOut, false);
    });

    test('postedAt in far future clamps remaining to 600', () {
      final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1000;
      notifier.processPollResponseForTest(
        CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: future.toString(),
        ),
      );
      expect(notifier.state.remaining, 600);
      expect(notifier.state.timedOut, false);
    });

    test('non-numeric postedAt treated as epoch 0', () {
      notifier.processPollResponseForTest(
        const CurrentSpeakerRequest(
          requestId: 'r1',
          status: 'waiting',
          postedAt: 'not-a-number',
        ),
      );
      expect(notifier.state.timedOut, true);
    });
  });

  group('PendingWaitState.copyWith preserves existing values', () {
    test('copyWith with no args preserves all', () {
      const s = PendingWaitState(
        requestId: 'r1',
        remaining: 400,
        timedOut: false,
        matchedRoomId: 'room1',
      );
      final s2 = s.copyWith();
      expect(s2.requestId, 'r1');
      expect(s2.remaining, 400);
      expect(s2.timedOut, false);
      expect(s2.matchedRoomId, 'room1');
    });

    test('clearRequest and clearMatch together', () {
      const s = PendingWaitState(requestId: 'r1', matchedRoomId: 'room1');
      final s2 = s.copyWith(clearRequest: true, clearMatch: true);
      expect(s2.requestId, isNull);
      expect(s2.matchedRoomId, isNull);
    });
  });
}
