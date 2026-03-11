/// Environment configuration — equivalent to NEXT_PUBLIC_* env vars.
class Env {
  Env._();

  /// Base URL for REST API calls (no trailing slash).
  /// On web, requests go through the same origin via `/api` prefix.
  /// On mobile, point to the actual backend host.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → host
  );

  /// WebSocket base URL (ws:// or wss://).
  static String get wsBaseUrl {
    final override = const String.fromEnvironment('WS_BASE_URL');
    if (override.isNotEmpty) return override;
    return apiBaseUrl.replaceFirst('http', 'ws');
  }

  /// Request timeout.
  static const Duration requestTimeout = Duration(seconds: 8);

  /// Tenant ID — set via --dart-define=TENANT_ID=xxx for multi-tenant builds.
  static const String tenantId = String.fromEnvironment('TENANT_ID', defaultValue: '');

  /// Board WebSocket URL.
  static String boardWsUrl(String token) =>
      '${wsBaseUrl}/board/ws?token=${Uri.encodeComponent(token)}';

  /// Chat WebSocket URL.
  static String chatWsUrl(String token, String roomId) =>
      '${wsBaseUrl}/chat/ws?token=${Uri.encodeComponent(token)}&room_id=${Uri.encodeComponent(roomId)}';
}
