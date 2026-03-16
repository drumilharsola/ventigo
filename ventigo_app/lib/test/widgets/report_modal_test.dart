import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ventigo_app/widgets/report_modal.dart';
import 'package:ventigo_app/services/api_client.dart';
import 'package:ventigo_app/state/auth_provider.dart';
import 'package:ventigo_app/state/board_provider.dart';
import 'package:ventigo_app/state/pending_wait_provider.dart';
import '../helpers/test_helpers.dart';

class _RecordingApiClient extends FakeApiClient {
  int submitReportCalls = 0;
  bool shouldThrowAuth = false;
  bool shouldThrowGeneric = false;

  @override
  Future<void> submitReport(String token, String reason,
      {String? detail, String? roomId}) async {
    submitReportCalls++;
    if (shouldThrowAuth) throw const AuthException('expired');
    if (shouldThrowGeneric) throw Exception('Server error');
  }
}

Widget _buildWidget({
  VoidCallback? onClose,
  String? roomId,
  _RecordingApiClient? api,
}) {
  final fakeApi = api ?? _RecordingApiClient();
  return ProviderScope(
    overrides: [
      authStorageProvider.overrideWithValue(FakeAuthStorage()),
      authProvider.overrideWith(
          (ref) => TestAuthNotifier(initial: kTestAuthState)),
      apiClientProvider.overrideWithValue(fakeApi),
      boardProvider.overrideWith((ref) => InertBoardNotifier(ref)),
      pendingWaitProvider.overrideWith((ref) => InertPendingWaitNotifier(ref)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReportModal(
            roomId: roomId,
            onClose: onClose ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ReportModal', () {
    const largeSize = Size(800, 1200);

    testWidgets('renders form with reason chips and text field',
        (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Report user'), findsOneWidget);
      expect(find.text('Select a reason:'), findsOneWidget);
      expect(find.text('Harassment'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('Hate speech'), findsOneWidget);
      expect(find.text('Inappropriate content'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('select reason chip', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      // Spam chip should now be selected (visual state change)
    });

    testWidgets('submit button disabled without reason', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _RecordingApiClient();
      await tester.pumpWidget(_buildWidget(api: api));
      await tester.pumpAndSettle();

      // Try tapping submit without selecting reason
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(api.submitReportCalls, 0);
    });

    testWidgets('successful submit shows success view', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _RecordingApiClient();
      bool closed = false;
      await tester.pumpWidget(
          _buildWidget(api: api, onClose: () => closed = true));
      await tester.pumpAndSettle();

      // Select a reason
      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      // Type details
      await tester.enterText(
          find.byType(TextField).first, 'Abusive language');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(api.submitReportCalls, 1);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);

      // Close success view
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(closed, true);
    });

    testWidgets('cancel calls onClose', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool closed = false;
      await tester.pumpWidget(_buildWidget(onClose: () => closed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(closed, true);
    });

    testWidgets('AuthException shows session expired', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _RecordingApiClient()..shouldThrowAuth = true;
      await tester.pumpWidget(_buildWidget(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Session expired'), findsOneWidget);
    });

    testWidgets('generic error shows message', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _RecordingApiClient()..shouldThrowGeneric = true;
      await tester.pumpWidget(_buildWidget(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server error'), findsOneWidget);
    });

    testWidgets('outer tap calls onClose', (tester) async {
      await tester.binding.setSurfaceSize(largeSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool closed = false;
      await tester.pumpWidget(_buildWidget(onClose: () => closed = true));
      await tester.pumpAndSettle();

      // Tap on the outer dark overlay
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(closed, true);
    });
  });
}
