import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment configuration for API and WebSocket endpoints.
class Env {
  Env._();

  static const String _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Base URL for REST API calls (no trailing slash).
  /// On web, defaults to same origin (empty string = relative paths).
  /// On mobile, defaults to production Render backend.
  /// Override with --dart-define=API_BASE_URL=https://...
  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    if (kIsWeb) return ''; // same-origin; requests use relative paths
    return 'https://unburden-backend-pvn9.onrender.com'; // production backend
  }

  /// WebSocket base URL (ws:// or wss://).
  static String get wsBaseUrl {
    final override = const String.fromEnvironment('WS_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kIsWeb && apiBaseUrl.isEmpty) {
      // Same-origin WebSocket: derive from window.location
      // Uri.base is 'http://host:port/' in Flutter web
      final base = Uri.base;
      final scheme = base.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    }
    return apiBaseUrl.replaceFirst('http', 'ws');
  }

  /// Request timeout.
  static const Duration requestTimeout = Duration(seconds: 8);

  /// Tenant ID - set via --dart-define=TENANT_ID=xxx for multi-tenant builds.
  static const String tenantId = String.fromEnvironment('TENANT_ID', defaultValue: '');

  /// Board WebSocket URL.
  static String boardWsUrl(String token) =>
      '${wsBaseUrl}/board/ws?token=${Uri.encodeComponent(token)}';

  /// Chat WebSocket URL.
  static String chatWsUrl(String token, String roomId) =>
      '${wsBaseUrl}/chat/ws?token=${Uri.encodeComponent(token)}&room_id=${Uri.encodeComponent(roomId)}';
}
