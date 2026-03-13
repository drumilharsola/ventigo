import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/brand.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'state/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: UnburdenApp()));
}

class UnburdenApp extends ConsumerStatefulWidget {
  const UnburdenApp({super.key});

  @override
  ConsumerState<UnburdenApp> createState() => _UnburdenAppState();
}

class _UnburdenAppState extends ConsumerState<UnburdenApp> {
  @override
  void initState() {
    super.initState();
    // Hydrate auth state from secure storage so the router can proceed.
    Future.microtask(() => ref.read(authProvider.notifier).hydrate());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
