import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/models/speaker_request.dart';
import '../helpers/test_helpers.dart';

class _TestBoardApi extends FakeApiClient {
  BoardResponse? boardResponse;
  int getBoardCalls = 0;

  @override
  Future<BoardResponse> getBoard(String token) async {
    getBoardCalls++;
    return boardResponse ??
        const BoardResponse(requests: [], myRequestId: null);
  }
}

ProviderContainer _buildContainer({_TestBoardApi? api}) {
  final fakeApi = api ?? _TestBoardApi();
  final container = ProviderContainer(overrides: [
    authStorageProvider.overrideWithValue(FakeAuthStorage()),
    authProvider.overrideWith(
        (ref) => TestAuthNotifier(initial: kTestAuthState)),
    apiClientProvider.overrideWithValue(fakeApi),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  // -- BoardState --
  group('BoardState', () {
    test('defaults', () {
      const s = BoardState();
      expect(s.requests, isEmpty);
      expect(s.myRequestId, isNull);
      expect(s.error, isNull);
    });

    test('copyWith', () {
      const s = BoardState();
      final s2 = s.copyWith(
        requests: const [
          SpeakerRequest(
              requestId: 'r1',
              sessionId: 's1',
              username: 'u1',
              avatarId: '1',
              postedAt: '0')
        ],
        myRequestId: 'r1',
        error: 'err',
      );
      expect(s2.requests.length, 1);
      expect(s2.myRequestId, 'r1');
      expect(s2.error, 'err');
    });

    test('clearMyRequest', () {
      final s =
          const BoardState(myRequestId: 'r1').copyWith(clearMyRequest: true);
      expect(s.myRequestId, isNull);
    });
  });

  // -- BoardNotifier handleMessage --
  group('BoardNotifier handleMessageForTest', () {
    late ProviderContainer container;
    late BoardNotifier notifier;

    setUp(() {
      container = _buildContainer();
      notifier = container.read(boardProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('board_state sets requests (filters own)', () {
      notifier.handleMessageForTest({
        'event': 'board_state',
        'requests': [
          {
            'request_id': 'r1',
            'session_id': 'other-session',
            'username': 'bob',
            'avatar_id': 1,
            'posted_at': '0'
          },
          {
            'request_id': 'r2',
            'session_id': 'test-session',
            'username': 'me',
            'avatar_id': 2,
            'posted_at': '0'
          },
        ],
        'my_request_id': 'r2',
      });
      // Own session filtered out
      expect(notifier.state.requests.length, 1);
      expect(notifier.state.requests.first.requestId, 'r1');
      expect(notifier.state.myRequestId, 'r2');
    });

    test('board_state clears myRequestId when null', () {
      notifier.handleMessageForTest({
        'event': 'board_state',
        'requests': [],
        'my_request_id': null,
      });
      expect(notifier.state.myRequestId, isNull);
    });

    test('new_request adds to list', () {
      notifier.handleMessageForTest({
        'event': 'new_request',
        'request_id': 'r3',
        'session_id': 'other',
        'username': 'alice',
        'avatar_id': 3,
        'posted_at': '1700000000',
      });
      expect(notifier.state.requests.length, 1);
      expect(notifier.state.requests.first.username, 'alice');
    });

    test('new_request from own session ignored', () {
      notifier.handleMessageForTest({
        'event': 'new_request',
        'request_id': 'r4',
        'session_id': 'test-session',
        'username': 'testuser',
        'avatar_id': 1,
        'posted_at': '0',
      });
      expect(notifier.state.requests, isEmpty);
    });

    test('new_request duplicate ignored', () {
      notifier.handleMessageForTest({
        'event': 'new_request',
        'request_id': 'r5',
        'session_id': 'other',
        'username': 'bob',
        'avatar_id': 1,
        'posted_at': '0',
      });
      notifier.handleMessageForTest({
        'event': 'new_request',
        'request_id': 'r5',
        'session_id': 'other',
        'username': 'bob',
        'avatar_id': 1,
        'posted_at': '0',
      });
      expect(notifier.state.requests.length, 1);
    });

    test('removed_request removes from list', () {
      notifier.handleMessageForTest({
        'event': 'new_request',
        'request_id': 'r6',
        'session_id': 'other',
        'username': 'carol',
        'avatar_id': 2,
        'posted_at': '0',
      });
      expect(notifier.state.requests.length, 1);
      notifier.handleMessageForTest({
        'event': 'removed_request',
        'request_id': 'r6',
      });
      expect(notifier.state.requests, isEmpty);
    });

    test('error token_invalid clears auth', () {
      notifier.handleMessageForTest({
        'event': 'error',
        'detail': 'token_invalid',
      });
      final auth = container.read(authProvider);
      expect(auth.token, isNull);
    });

    test('error session_replaced clears auth', () {
      notifier.handleMessageForTest({
        'event': 'error',
        'detail': 'session_replaced',
      });
      final auth = container.read(authProvider);
      expect(auth.token, isNull);
    });

    test('matched event does nothing to state', () {
      final before = notifier.state;
      notifier.handleMessageForTest({
        'event': 'matched',
        'room_id': 'some-room',
      });
      expect(notifier.state.requests, before.requests);
    });

    test('board_state with null requests defaults to empty', () {
      notifier.handleMessageForTest({
        'event': 'board_state',
        'requests': null,
        'my_request_id': null,
      });
      expect(notifier.state.requests, isEmpty);
    });
  });

  // -- syncBoard --
  group('BoardNotifier syncBoard', () {
    test('success updates state', () async {
      final api = _TestBoardApi()
        ..boardResponse = const BoardResponse(
          requests: [
            SpeakerRequest(
                requestId: 'r1',
                sessionId: 'other',
                username: 'peer',
                avatarId: '1',
                postedAt: '0'),
          ],
          myRequestId: 'my1',
        );
      final container = _buildContainer(api: api);
      final notifier = container.read(boardProvider.notifier);
      await notifier.syncBoard();
      expect(api.getBoardCalls, 1);
      expect(notifier.state.requests.length, 1);
      expect(notifier.state.myRequestId, 'my1');
    });

    test('error sets error', () async {
      final api = _TestBoardApi();
      // Override getBoard to throw
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: kTestAuthState)),
        apiClientProvider.overrideWithValue(_ErrorBoardApi()),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(boardProvider.notifier);
      await notifier.syncBoard();
      expect(notifier.state.error, isNotNull);
    });

    test('no-op without token', () async {
      final container = ProviderContainer(overrides: [
        authStorageProvider.overrideWithValue(FakeAuthStorage()),
        authProvider.overrideWith(
            (ref) => TestAuthNotifier(initial: const AuthState())),
        apiClientProvider.overrideWithValue(_TestBoardApi()),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(boardProvider.notifier);
      await notifier.syncBoard();
      final api = container.read(apiClientProvider) as _TestBoardApi;
      expect(api.getBoardCalls, 0);
    });
  });
}

class _ErrorBoardApi extends FakeApiClient {
  @override
  Future<BoardResponse> getBoard(String token) async {
    throw Exception('network error');
  }
}
