
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';

import '../screens/landing_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/verify_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/blocked_users_screen.dart';
import '../screens/main_shell.dart';
import '../screens/chat_screen.dart';
import '../screens/unified_chat_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_user_detail_screen.dart';
import '../screens/admin/admin_analytics_screen.dart';
import '../screens/admin/admin_tenants_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/terms_screen.dart';

// ── Route path constants ─────────────────────────────────────────────────────
const kPathVerify = '/verify';
const kPathOnboarding = '/onboarding';
const kPathHome = '/home';
const kPathProfile = '/profile';

/// Bridges Riverpod [AuthState] changes into a [Listenable] so the single
/// GoRouter instance can re-evaluate its redirect without being recreated.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      debugPrint('[ROUTER] redirect: path=$path hydrated=${auth.hasHydrated} loggedIn=${auth.isLoggedIn} hasProfile=${auth.hasProfile}');
      if (!auth.hasHydrated) return null; // wait for hydration

      final loggedIn = auth.isLoggedIn;
      final hasProfile = auth.hasProfile;

      // If logged in with profile and on landing/verify/onboarding → go to home
      if (loggedIn && hasProfile && (path == '/' || path == kPathVerify || path == kPathOnboarding)) {
        return kPathHome;
      }
      // Legacy lobby redirect
      if (path == '/lobby') return '/home';

      // Public routes - no redirect needed.
      const publicPaths = {'/', kPathOnboarding, kPathVerify, '/verify-email', '/brand', '/privacy', '/terms'};
      // Admin routes need auth but are handled by the admin screens themselves
      if (publicPaths.contains(path) || path.startsWith('/admin')) return null;

      // If not logged in, send to verify.
      if (!loggedIn) return kPathVerify;

      // If logged in but no profile, send to profile setup.
      if (!hasProfile && path != kPathProfile) return kPathProfile;

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: kPathOnboarding, builder: (_, state) {
        final intent = state.uri.queryParameters['intent'];
        return OnboardingScreen(intent: intent);
      }),
      GoRoute(path: kPathVerify, builder: (_, state) {
        final resetToken = state.uri.queryParameters['reset_token'];
        return VerifyScreen(resetToken: resetToken);
      }),
      GoRoute(path: '/verify-email', builder: (_, state) {
        final status = state.uri.queryParameters['status'] ?? '';
        return VerifyEmailScreen(status: status);
      }),
      GoRoute(path: kPathProfile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/blocked-users', builder: (_, __) => const BlockedUsersScreen()),

      // ── Main shell with bottom navigation ──
      GoRoute(path: kPathHome, builder: (_, __) => const MainShell(initialIndex: 0)),
      GoRoute(path: '/chats', builder: (_, __) => const MainShell(initialIndex: 1)),
      GoRoute(path: '/posts', builder: (_, __) => const MainShell(initialIndex: 2)),
      GoRoute(path: '/help', builder: (_, __) => const MainShell(initialIndex: 3)),
      GoRoute(path: '/me', builder: (_, __) => const MainShell(initialIndex: 4)),

      // ── Full-screen routes (no bottom nav) ──
      GoRoute(path: '/chat', builder: (_, state) {
        final roomId = state.uri.queryParameters['room_id'] ?? '';
        final peerSessionId = state.uri.queryParameters['peer_session_id'] ?? '';
        return ChatScreen(roomId: roomId, peerSessionId: peerSessionId);
      }),
      GoRoute(path: '/unified-chat', builder: (_, state) {
        final peerSessionId = state.uri.queryParameters['peer_session_id'] ?? '';
        final peerUsername = state.uri.queryParameters['peer_username'] ?? '';
        return UnifiedChatScreen(peerSessionId: peerSessionId, peerUsername: peerUsername);
      }),

      // ── Admin ──
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/analytics', builder: (_, __) => const AdminAnalyticsScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUserDetailScreen()),
      GoRoute(path: '/admin/tenants', builder: (_, __) => const AdminTenantsScreen()),

      // ── Static pages ──
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
    ],
  );
});


