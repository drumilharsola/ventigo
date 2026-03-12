
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import '../screens/landing_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/verify_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/lobby_screen.dart';
import '../screens/waiting_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/history_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_user_detail_screen.dart';
import '../screens/admin/admin_analytics_screen.dart';
import '../screens/admin/admin_tenants_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/terms_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      if (!auth.hasHydrated) return null; // wait for hydration

      final loggedIn = auth.isLoggedIn;
      final hasProfile = auth.hasProfile;
      final path = state.uri.path;

      // Public routes — no redirect needed.
      const publicPaths = {'/', '/onboarding', '/verify', '/verify-email', '/brand', '/privacy', '/terms'};
      // Admin routes need auth but are handled by the admin screens themselves
      if (publicPaths.contains(path) || path.startsWith('/admin')) return null;

      // If not logged in, send to verify.
      if (!loggedIn) return '/verify';

      // If logged in but no profile, send to profile setup.
      if (!hasProfile && path != '/profile') return '/profile';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/onboarding', builder: (_, state) {
        final intent = state.uri.queryParameters['intent'];
        return OnboardingScreen(intent: intent);
      }),
      GoRoute(path: '/verify', builder: (_, __) => const VerifyScreen()),
      GoRoute(path: '/verify-email', builder: (_, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return VerifyEmailScreen(token: token);
      }),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/lobby', builder: (_, state) {
        final requestId = state.uri.queryParameters['request_id'];
        return LobbyScreen(requestId: requestId);
      }),
      GoRoute(path: '/waiting', builder: (_, state) {
        final requestId = state.uri.queryParameters['request_id'] ?? '';
        return WaitingScreen(requestId: requestId);
      }),
      GoRoute(path: '/chat', builder: (_, state) {
        final roomId = state.uri.queryParameters['room_id'] ?? '';
        final peerSessionId = state.uri.queryParameters['peer_session_id'] ?? '';
        return ChatScreen(roomId: roomId, peerSessionId: peerSessionId);
      }),
      GoRoute(path: '/history', builder: (_, state) {
        final tab = state.uri.queryParameters['tab'];
        return HistoryScreen(tab: tab);
      }),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/analytics', builder: (_, __) => const AdminAnalyticsScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUserDetailScreen()),
      GoRoute(path: '/admin/tenants', builder: (_, __) => const AdminTenantsScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
    ],
  );
});
