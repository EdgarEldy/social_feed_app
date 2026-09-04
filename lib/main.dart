import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/di/injection_container.dart';

Future<void> main() async {
  // Widget binding must be ready before any plugin call (dotenv.load reads
  // a bundled asset through the platform channel) that happens before
  // runApp.
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // Wires the dependency graph (Dio, GoRouter, and everything later
  // branches add) once, before the widget tree is built, so every
  // getIt<T>() call made while rendering resolves successfully.
  configureDependencies();

  runApp(const App());
}
