import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Persistent WebSocket connection with auto-reconnect.
///
/// Used for both the board channel and the chat channel.
class WsService {
  final String Function() _urlBuilder;
  final void Function(Map<String, dynamic> event) _onEvent;
  final void Function()? onConnected;
  final void Function()? onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionallyClosed = false;

  static const _reconnectDelay = Duration(seconds: 3);

  WsService({
    required String Function() urlBuilder,
    required void Function(Map<String, dynamic> event) onEvent,
    this.onConnected,
    this.onDisconnected,
  })  : _urlBuilder = urlBuilder,
        _onEvent = onEvent;

  bool get isConnected => _channel != null;

  void connect() {
    if (_disposed) return;
    _intentionallyClosed = false;
    _close();

    final url = _urlBuilder();
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _subscription = _channel!.stream.listen(
      (raw) {
        if (raw is String) {
          try {
            final data = json.decode(raw) as Map<String, dynamic>;
            _onEvent(data);
          } catch (_) {}
        }
      },
      onDone: () {
        onDisconnected?.call();
        _scheduleReconnect();
      },
      onError: (_) {
        onDisconnected?.call();
        _scheduleReconnect();
      },
    );

    onConnected?.call();
  }

  void send(Map<String, dynamic> data) {
    _channel?.sink.add(json.encode(data));
  }

  void close() {
    _intentionallyClosed = true;
    _close();
  }

  void dispose() {
    _disposed = true;
    _intentionallyClosed = true;
    _close();
  }

  void _close() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionallyClosed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, connect);
  }
}
