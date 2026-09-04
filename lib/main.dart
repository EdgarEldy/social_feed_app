import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/di/injection_container.dart';

Future<void> main() async {
  // Widget binding must be ready before any plugin call (dotenv.load reads
  // a bundled asset through the platform channel) that happens before
  // runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');

    // Wires the dependency graph (Dio, GoRouter, and everything later
    // branches add) once, before the widget tree is built, so every
    // getIt<T>() call made while rendering resolves successfully.
    configureDependencies();

    runApp(const App());
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
