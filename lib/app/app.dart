import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';

/// Root widget of the application.
///
/// `MaterialApp.router` hands navigation control to the [GoRouter]
/// registered in `get_it` instead of the classic `Navigator`/`routes` map,
/// so every screen is reachable by URL and route parameters flow through
/// `GoRouterState`. Real theming (light/dark `ColorScheme`, typography) is
/// built in `feature/design-system`; this is a minimal Material 3 theme so
/// the app has something reasonable to render until then.
class App extends StatelessWidget {
  /// Creates the root widget.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SocialFeed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: getIt<GoRouter>(),
    );
  }
}
