import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'config/brand.dart';
import 'config/env.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'state/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -- OneSignal ------------------------------------------------------------
  if (Env.onesignalAppId.isNotEmpty) {
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(Env.onesignalAppId);
    OneSignal.Notifications.requestPermission(true);
    // Notification click handler - navigate based on notification data
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      final type = data['type'] as String?;
      // Navigation handled via GoRouter in the app - deep link based on type
      // Community notifications (kudos, comments) → /community
      // Appreciation → /me (profile)
      // We don't send chat notifications per user's requirement
      debugPrint('[OneSignal] Notification clicked: type=$type');
    });
  }

  // -- PostHog (product analytics) ------------------------------------------
  if (Env.posthogApiKey.isNotEmpty) {
    final config = PostHogConfig(Env.posthogApiKey);
    config.host = Env.posthogHost;
    config.captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
  }

  // -- Sentry ---------------------------------------------------------------
  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = Env.environment;
        options.sendDefaultPii = false;
      },
      appRunner: () => runApp(const ProviderScope(child: VentigoApp())),
    );
  } else {
    runApp(const ProviderScope(child: VentigoApp()));
  }
}

class VentigoApp extends ConsumerStatefulWidget {
  const VentigoApp({super.key});

  @override
  ConsumerState<VentigoApp> createState() => _VentigoAppState();
}

class _VentigoAppState extends ConsumerState<VentigoApp> {
  bool _ready = false;
  late final ThemeData _theme = buildAppTheme();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ref.read(authProvider.notifier).hydrate();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;

    if (!_ready) {
      return MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,

    );
  }
}
