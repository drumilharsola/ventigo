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
  bool _ready = false;

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
    final theme = buildAppTheme();

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
