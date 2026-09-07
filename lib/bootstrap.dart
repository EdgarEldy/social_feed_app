import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/di/injection_container.dart';
import 'core/sync/sync_service.dart';
import 'features/auth/presentation/stores/auth_store.dart';

/// Shared startup sequence for every flavor entry point (`main.dart`,
/// `main_development.dart`, `main_production.dart`). Each entry point only
/// differs in which `.env.<flavor>` file it hands in as [envFileName]; the
/// rest of the startup work (loading env values, wiring the dependency
/// graph, restoring the session, starting the sync service, and falling
/// back to an error screen) is identical across flavors, so it lives here
/// once instead of being copy-pasted per entry point.
Future<void> bootstrap({required String envFileName}) async {
  // Widget binding must be ready before any plugin call (dotenv.load reads
  // a bundled asset through the platform channel) that happens before
  // runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: envFileName);

    // Wires the dependency graph (Dio, GoRouter, and everything later
    // branches add) once, before the widget tree is built, so every
    // getIt<T>() call made while rendering resolves successfully.
    configureDependencies();

    // Reads the stored tokens and, if present, provisionally restores the
    // authenticated state (see AuthStore's class doc for exactly what that
    // means) before the widget tree, and with it go_router's first redirect
    // decision, is built.
    await getIt<AuthStore>().restoreSession();

    // SyncService is a registerLazySingleton, so nothing constructs it (and
    // with it, calls .start() to begin watching ConnectivityStore) until
    // something resolves it. It has no widget of its own the way
    // ConnectivityStore does through ConnectivityAwareOfflineBanner, so it
    // is resolved here explicitly, once, before the widget tree is built.
    getIt<SyncService>();

    runApp(App());
  } catch (error) {
    // Neither dotenv.load nor configureDependencies has a UI to fail into,
    // so an uncaught exception here would kill the app before any widget
    // mounts. Falling back to a minimal error screen at least gives a
    // diagnosable message instead of a silent crash.
    runApp(_StartupErrorApp(message: error.toString()));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to start the app:\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
