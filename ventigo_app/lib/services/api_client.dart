import 'package:dio/dio.dart';
import '../config/env.dart';
import '../models/speaker_request.dart';
import '../models/room_summary.dart';
import '../models/room_messages.dart';
import '../models/blocked_user.dart';
import '../models/user_profile.dart';
import '../models/appreciation.dart';
import '../models/current_speaker_request.dart';

/// Thrown on 401 responses - mirrors AuthError from api.ts.
const _kNotAuthenticated = 'Not authenticated';

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = _kNotAuthenticated]);
  @override
  String toString() => message;
}

/// Dio-based REST client - direct port of the `api` object in api.ts.
class ApiClient {
  late final Dio _dio;

  ApiClient({Dio? dio}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.requestTimeout,
      receiveTimeout: Env.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        if (Env.tenantId.isNotEmpty) 'X-Tenant-ID': Env.tenantId,
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          final detail = error.response?.data is Map
              ? (error.response!.data as Map)['detail'] ?? _kNotAuthenticated
              : _kNotAuthenticated;
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: AuthException(detail.toString()),
          ));
        }
        handler.next(error);
      },
    ));
  }

  Map<String, String> _authHeader(String token) =>
      {'Authorization': 'Bearer $token'};

  /// Unwrap Dio errors into clean messages.
  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.error is AuthException) throw e.error!;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('The server took too long to respond. Please try again.');
      }
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        throw Exception(data['detail'].toString());
      }
      throw Exception('Cannot reach the server right now. Please try again in a moment.');
    }
    throw e;
  }

  // -------------------------- AUTH --------------------------

  Future<AuthResponse> register(String email, String password) async {
    try {
      final res = await _dio.post('/auth/register', data: {'email': email, 'password': password});
      return AuthResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      return AuthResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<void> sendVerification(String token) async {
    try {
      await _dio.post('/auth/send-verification', options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<AuthResponse> verifyEmail(String verifyToken) async {
    try {
      final res = await _dio.get('/auth/verify-email', queryParameters: {'token': verifyToken});
      return AuthResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/auth/forgot-password', data: {'email': email});
    } catch (e) { _rethrow(e); }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _dio.post('/auth/reset-password', data: {'token': token, 'new_password': newPassword});
    } catch (e) { _rethrow(e); }
  }

  Future<void> changePassword(String token, String currentPassword, String newPassword) async {
    try {
      await _dio.post('/auth/change-password',
          data: {'current_password': currentPassword, 'new_password': newPassword},
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> changeEmail(String token, String newEmail, String password) async {
    try {
      await _dio.post('/auth/change-email',
          data: {'new_email': newEmail, 'password': password},
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<ProfileSetupResponse> setProfile(String token, {required String dob, required int avatarId}) async {
    try {
      final res = await _dio.post('/auth/profile',
          data: {'dob': dob, 'avatar_id': avatarId},
          options: Options(headers: _authHeader(token)));
      return ProfileSetupResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<UserProfile> getMe(String token) async {
    try {
      final res = await _dio.get('/auth/me', options: Options(headers: _authHeader(token)));
      return UserProfile.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<ProfileSetupResponse> updateProfile(String token, {int? avatarId, bool? rerollUsername}) async {
    try {
      final res = await _dio.patch('/auth/profile',
          data: {
            if (avatarId != null) 'avatar_id': avatarId,
            if (rerollUsername != null) 'reroll_username': rerollUsername,
          },
          options: Options(headers: _authHeader(token)));
      return ProfileSetupResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<UserProfile> getUserProfile(String token, String username) async {
    try {
      final res = await _dio.get('/auth/user/${Uri.encodeComponent(username)}',
          options: Options(headers: _authHeader(token)));
      return UserProfile.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- BOARD --------------------------

  Future<BoardResponse> getBoard(String token) async {
    try {
      final res = await _dio.get('/board/requests', options: Options(headers: _authHeader(token)));
      return BoardResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<SpeakResponse> postSpeak(String token, {String topic = ''}) async {
    try {
      final res = await _dio.post('/board/speak',
          data: {'topic': topic},
          options: Options(headers: _authHeader(token)));
      return SpeakResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<void> cancelSpeak(String token) async {
    try {
      await _dio.delete('/board/speak', options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<CurrentSpeakerRequest> getSpeakerRequest(String token, String requestId) async {
    try {
      final res = await _dio.get('/board/request/${Uri.encodeComponent(requestId)}',
          options: Options(headers: _authHeader(token)));
      return CurrentSpeakerRequest.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<AcceptResponse> acceptSpeaker(String token, String requestId) async {
    try {
      final res = await _dio.post('/board/accept/${Uri.encodeComponent(requestId)}',
          options: Options(headers: _authHeader(token)));
      return AcceptResponse.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- REPORT --------------------------

  Future<void> submitReport(String token, String reason, {String? detail, String? roomId}) async {
    try {
      await _dio.post('/report/', data: {
        'reason': reason,
        'detail': detail ?? '',
        if (roomId != null) 'room_id': roomId,
      }, options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- BLOCK --------------------------

  Future<void> blockUser(String token, String peerSessionId, String username, int avatarId) async {
    try {
      await _dio.post('/block', data: {
        'peer_session_id': peerSessionId,
        'username': username,
        'avatar_id': avatarId,
      }, options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> unblockUser(String token, String peerSessionId) async {
    try {
      await _dio.delete('/block/${Uri.encodeComponent(peerSessionId)}',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<List<BlockedUser>> getBlockedUsers(String token) async {
    try {
      final res = await _dio.get('/block', options: Options(headers: _authHeader(token)));
      return (res.data['blocked'] as List)
          .map((j) => BlockedUser.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- CHAT / ROOMS --------------------------

  Future<String?> getActiveRoom(String token) async {
    try {
      final res = await _dio.get('/chat/active', options: Options(headers: _authHeader(token)));
      return res.data['room_id'] as String?;
    } catch (e) { _rethrow(e); }
  }

  Future<List<RoomSummary>> getChatRooms(String token) async {
    try {
      final res = await _dio.get('/chat/rooms', options: Options(headers: _authHeader(token)));
      return (res.data['rooms'] as List)
          .map((j) => RoomSummary.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { _rethrow(e); }
  }

  Future<RoomMessages> getRoomMessages(String token, String roomId) async {
    try {
      final res = await _dio.get('/chat/rooms/${Uri.encodeComponent(roomId)}/messages',
          options: Options(headers: _authHeader(token)));
      return RoomMessages.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- FEEDBACK --------------------------

  Future<void> postFeedback(String token, String roomId, String mood, {String text = ''}) async {
    try {
      await _dio.post('/chat/rooms/${Uri.encodeComponent(roomId)}/feedback',
          data: {'mood': mood, 'text': text},
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- APPRECIATION --------------------------

  Future<Map<String, dynamic>> postAppreciation(String token, String roomId, String message) async {
    try {
      final res = await _dio.post('/chat/rooms/${Uri.encodeComponent(roomId)}/appreciate',
          data: {'message': message},
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<List<Appreciation>> getAppreciations(String token, String username, {int limit = 20, int offset = 0}) async {
    try {
      final res = await _dio.get('/auth/user/${Uri.encodeComponent(username)}/appreciations',
          queryParameters: {'limit': limit, 'offset': offset},
          options: Options(headers: _authHeader(token)));
      final list = (res.data['appreciations'] as List?) ?? [];
      return list.map((e) => Appreciation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- CONNECTIONS --------------------------

  Future<Map<String, dynamic>> sendConnectionRequest(String token, String peerSessionId) async {
    try {
      final res = await _dio.post('/chat/connect/${Uri.encodeComponent(peerSessionId)}',
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<void> acceptConnectionRequest(String token, String peerSessionId) async {
    try {
      await _dio.post('/chat/connect/${Uri.encodeComponent(peerSessionId)}/accept',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> removeConnection(String token, String peerSessionId) async {
    try {
      await _dio.delete('/chat/connect/${Uri.encodeComponent(peerSessionId)}',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<Map<String, dynamic>> getConnections(String token) async {
    try {
      final res = await _dio.get('/chat/connections',
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<String> directChat(String token, String peerSessionId) async {
    try {
      final res = await _dio.post('/chat/connect/${Uri.encodeComponent(peerSessionId)}/chat',
          options: Options(headers: _authHeader(token)));
      return res.data['room_id'] as String;
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- POSTS --------------------------

  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final res = await _dio.get('/posts');
      final list = res.data['posts'] as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) { _rethrow(e); }
  }

  Future<Map<String, dynamic>> createPost(String token, String text) async {
    try {
      final res = await _dio.post('/posts',
          data: {'text': text},
          options: Options(headers: _authHeader(token)));
      return res.data['post'] as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<void> deletePost(String token, String postId) async {
    try {
      await _dio.delete('/posts/${Uri.encodeComponent(postId)}',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<Map<String, dynamic>> toggleKudos(String token, String postId) async {
    try {
      final res = await _dio.post('/posts/${Uri.encodeComponent(postId)}/kudos',
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<Map<String, dynamic>> getKudos(String token, String postId) async {
    try {
      final res = await _dio.get('/posts/${Uri.encodeComponent(postId)}/kudos',
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final res = await _dio.get('/posts/${Uri.encodeComponent(postId)}/comments');
      final list = res.data['comments'] as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) { _rethrow(e); }
  }

  Future<Map<String, dynamic>> addComment(String token, String postId, String text) async {
    try {
      final res = await _dio.post('/posts/${Uri.encodeComponent(postId)}/comments',
          data: {'text': text},
          options: Options(headers: _authHeader(token)));
      return res.data['comment'] as Map<String, dynamic>;
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- GDPR --------------------------

  Future<Map<String, dynamic>> exportData(String token) async {
    try {
      final res = await _dio.get('/auth/export',
          options: Options(headers: _authHeader(token)));
      return res.data as Map<String, dynamic>;
    } catch (e) { _rethrow(e); rethrow; }
  }

  Future<void> deleteAccount(String token) async {
    try {
      await _dio.delete('/auth/account',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  // -------------------------- ADMIN --------------------------

  Future<AdminStats> adminStats(String token) async {
    try {
      final res = await _dio.get('/admin/stats', options: Options(headers: _authHeader(token)));
      return AdminStats.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<List<AdminReport>> adminListReports(String token, {int offset = 0, int limit = 50}) async {
    try {
      final res = await _dio.get('/admin/reports',
          queryParameters: {'offset': offset, 'limit': limit},
          options: Options(headers: _authHeader(token)));
      return (res.data['reports'] as List)
          .map((j) => AdminReport.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { _rethrow(e); }
  }

  Future<AdminUser> adminGetUser(String token, String sessionId) async {
    try {
      final res = await _dio.get('/admin/users/${Uri.encodeComponent(sessionId)}',
          options: Options(headers: _authHeader(token)));
      return AdminUser.fromJson(res.data);
    } catch (e) { _rethrow(e); }
  }

  Future<void> adminSuspendUser(String token, String sessionId) async {
    try {
      await _dio.post('/admin/users/${Uri.encodeComponent(sessionId)}/suspend',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> adminUnsuspendUser(String token, String sessionId) async {
    try {
      await _dio.delete('/admin/users/${Uri.encodeComponent(sessionId)}/suspend',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> adminGrantModerator(String token, String sessionId) async {
    try {
      await _dio.post('/admin/moderators',
          data: {'session_id': sessionId},
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<void> adminRevokeModerator(String token, String sessionId) async {
    try {
      await _dio.delete('/admin/moderators/${Uri.encodeComponent(sessionId)}',
          options: Options(headers: _authHeader(token)));
    } catch (e) { _rethrow(e); }
  }

  Future<AnalyticsOverview> adminAnalyticsOverview(String token) async {
    try {
      final res = await _dio.get('/admin/analytics/overview',
          options: Options(headers: _authHeader(token)));
      return AnalyticsOverview.fromJson(res.data);
    } catch (e) { _rethrow(e); rethrow; }
  }

  Future<List<TimeseriesPoint>> adminAnalyticsTimeseries(
      String token, String metric, String fromDate, String toDate) async {
    try {
      final res = await _dio.get('/admin/analytics/timeseries',
          queryParameters: {'metric': metric, 'from_date': fromDate, 'to_date': toDate},
          options: Options(headers: _authHeader(token)));
      final list = (res.data['data'] as List?) ?? [];
      return list.map((e) => TimeseriesPoint.fromJson(e)).toList();
    } catch (e) { _rethrow(e); rethrow; }
  }

  // -------------------------- TENANT MANAGEMENT --------------------------

  Map<String, String> _adminKeyHeader(String adminKey) =>
      {'X-Admin-Key': adminKey};

  Future<List<Tenant>> adminListTenants(String adminKey) async {
    try {
      final res = await _dio.get('/admin/tenants',
          options: Options(headers: _adminKeyHeader(adminKey)));
      return (res.data['tenants'] as List)
          .map((j) => Tenant.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { _rethrow(e); rethrow; }
  }

  Future<Tenant> adminCreateTenant(String adminKey, {
    required String tenantId,
    required String name,
    String domain = '',
  }) async {
    try {
      final res = await _dio.post('/admin/tenants',
          data: {'tenant_id': tenantId, 'name': name, 'domain': domain},
          options: Options(headers: _adminKeyHeader(adminKey)));
      return Tenant.fromJson(res.data);
    } catch (e) { _rethrow(e); rethrow; }
  }

  Future<Tenant> adminUpdateTenant(String adminKey, String tenantId, {
    bool? active,
    String? name,
    String? domain,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (active != null) body['active'] = active;
      if (name != null) body['name'] = name;
      if (domain != null) body['domain'] = domain;
      final res = await _dio.patch('/admin/tenants/${Uri.encodeComponent(tenantId)}',
          data: body,
          options: Options(headers: _adminKeyHeader(adminKey)));
      return Tenant.fromJson(res.data);
    } catch (e) { _rethrow(e); rethrow; }
  }
}

// -------------------------- Response DTOs --------------------------

class AuthResponse {
  final String token;
  final String sessionId;
  final bool hasProfile;
  final bool emailVerified;

  const AuthResponse({
    required this.token,
    required this.sessionId,
    required this.hasProfile,
    required this.emailVerified,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        sessionId: json['session_id'] as String,
        hasProfile: json['has_profile'] as bool,
        emailVerified: json['email_verified'] as bool,
      );
}

class ProfileSetupResponse {
  final String username;
  final int avatarId;

  const ProfileSetupResponse({required this.username, required this.avatarId});

  factory ProfileSetupResponse.fromJson(Map<String, dynamic> json) =>
      ProfileSetupResponse(
        username: json['username'] as String,
        avatarId: (json['avatar_id'] as num).toInt(),
      );
}

class BoardResponse {
  final List<SpeakerRequest> requests;
  final String? myRequestId;

  const BoardResponse({required this.requests, this.myRequestId});

  factory BoardResponse.fromJson(Map<String, dynamic> json) => BoardResponse(
        requests: (json['requests'] as List)
            .map((j) => SpeakerRequest.fromJson(j as Map<String, dynamic>))
            .toList(),
        myRequestId: json['my_request_id'] as String?,
      );
}

class SpeakResponse {
  final String requestId;
  final String status;

  const SpeakResponse({required this.requestId, required this.status});

  factory SpeakResponse.fromJson(Map<String, dynamic> json) => SpeakResponse(
        requestId: json['request_id'] as String,
        status: json['status'] as String,
      );
}

class AcceptResponse {
  final String roomId;

  const AcceptResponse({required this.roomId});

  factory AcceptResponse.fromJson(Map<String, dynamic> json) =>
      AcceptResponse(roomId: json['room_id'] as String);
}

// -------------------------- Admin Response DTOs --------------------------

class AdminStats {
  final int activeRooms;
  final int queuedUsers;
  final int boardRequests;
  final int totalReports;

  const AdminStats({
    required this.activeRooms,
    required this.queuedUsers,
    required this.boardRequests,
    required this.totalReports,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        activeRooms: (json['active_rooms'] as num).toInt(),
        queuedUsers: (json['queued_users'] as num).toInt(),
        boardRequests: (json['board_requests'] as num).toInt(),
        totalReports: (json['total_reports'] as num).toInt(),
      );
}

class AdminReport {
  final String reportId;
  final String reporterSession;
  final String reportedSession;
  final String roomId;
  final String reason;
  final String detail;
  final String ts;

  const AdminReport({
    required this.reportId,
    required this.reporterSession,
    required this.reportedSession,
    required this.roomId,
    required this.reason,
    required this.detail,
    required this.ts,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
        reportId: json['report_id'] as String? ?? '',
        reporterSession: json['reporter_session'] as String? ?? '',
        reportedSession: json['reported_session'] as String? ?? '',
        roomId: json['room_id'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        ts: json['ts'] as String? ?? '',
      );
}

class AdminUser {
  final String sessionId;
  final String username;
  final String avatarId;
  final String speakCount;
  final String listenCount;
  final String createdAt;
  final String emailVerified;
  final String suspended;
  final String isAdmin;
  final int reportCount;

  const AdminUser({
    required this.sessionId,
    required this.username,
    required this.avatarId,
    required this.speakCount,
    required this.listenCount,
    required this.createdAt,
    required this.emailVerified,
    required this.suspended,
    required this.isAdmin,
    required this.reportCount,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        sessionId: json['session_id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        avatarId: json['avatar_id']?.toString() ?? '0',
        speakCount: json['speak_count']?.toString() ?? '0',
        listenCount: json['listen_count']?.toString() ?? '0',
        createdAt: json['created_at']?.toString() ?? '',
        emailVerified: json['email_verified']?.toString() ?? '0',
        suspended: json['suspended']?.toString() ?? '0',
        isAdmin: json['is_admin']?.toString() ?? '0',
        reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
      );
}

class AnalyticsOverview {
  final int dau;
  final int mau;
  final int sessionsToday;
  final int registrationsToday;
  final int reportsToday;
  final int boardPostsToday;
  final int avgSessionDuration;

  const AnalyticsOverview({
    required this.dau,
    required this.mau,
    required this.sessionsToday,
    required this.registrationsToday,
    required this.reportsToday,
    required this.boardPostsToday,
    required this.avgSessionDuration,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverview(
        dau: (json['dau'] as num?)?.toInt() ?? 0,
        mau: (json['mau'] as num?)?.toInt() ?? 0,
        sessionsToday: (json['sessions_today'] as num?)?.toInt() ?? 0,
        registrationsToday: (json['registrations_today'] as num?)?.toInt() ?? 0,
        reportsToday: (json['reports_today'] as num?)?.toInt() ?? 0,
        boardPostsToday: (json['board_posts_today'] as num?)?.toInt() ?? 0,
        avgSessionDuration: (json['avg_session_duration'] as num?)?.toInt() ?? 0,
      );
}

class TimeseriesPoint {
  final String date;
  final int value;

  const TimeseriesPoint({required this.date, required this.value});

  factory TimeseriesPoint.fromJson(Map<String, dynamic> json) =>
      TimeseriesPoint(
        date: json['date'] as String? ?? '',
        value: (json['value'] as num?)?.toInt() ?? 0,
      );
}

class Tenant {
  final String tenantId;
  final String name;
  final String domain;
  final bool active;
  final double createdAt;

  const Tenant({
    required this.tenantId,
    required this.name,
    required this.domain,
    required this.active,
    required this.createdAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        tenantId: json['tenant_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        createdAt: (json['created_at'] as num?)?.toDouble() ?? 0,
      );
}
