import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'state/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Hydrate auth from secure storage before first frame.
  await container.read(authProvider.notifier).hydrate();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UnburdenApp(),
    ),
  );
}
