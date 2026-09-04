import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';
import '../core/l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

/// Root widget of the application.
///
/// `MaterialApp.router` hands navigation control to the [GoRouter]
/// registered in `get_it` instead of the classic `Navigator`/`routes` map,
/// so every screen is reachable by URL and route parameters flow through
/// `GoRouterState`.
///
/// Theming is a [StatefulWidget] concern here rather than a `MobX` one: the
/// app owns a [ThemeModeController], listens to it, and rebuilds whenever
/// the user picks a manual light/dark override. When the controller is left
/// on [ThemeMode.system] (the default), the effective brightness is read
/// explicitly via [MediaQuery.platformBrightnessOf] on every build, so the
/// theme also updates live if the OS brightness changes while the app is
/// running.
class App extends StatefulWidget {
  /// Creates the root widget.
  ///
  /// [themeModeController] can be supplied by a caller (mainly tests) that
  /// wants to control or observe the theme mode from the outside; when
  /// omitted, the widget owns its own controller and disposes it.
  App({super.key, ThemeModeController? themeModeController})
      : themeModeController = themeModeController ?? ThemeModeController();

  /// Tracks the user's manual theme override, defaulting to "follow system".
  final ThemeModeController themeModeController;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    widget.themeModeController.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    widget.themeModeController.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.themeModeController;

    // ThemeMode.system would normally let MaterialApp resolve the platform
    // brightness internally. Reading it explicitly through MediaQuery here
    // instead keeps the resolution visible and, just as importantly, makes
    // this build method a MediaQuery dependent, so it reruns automatically
    // whenever the OS brightness setting changes.
    final effectiveBrightness = switch (controller.mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

    return MaterialApp.router(
      title: 'SocialFeed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: effectiveBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: getIt<GoRouter>(),
    );
  }
}
