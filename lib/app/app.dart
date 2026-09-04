import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';
import '../core/l10n/app_localizations.dart';
import '../core/widgets/connectivity_aware_offline_banner.dart';
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
/// the user picks a manual light/dark override. The controller's [ThemeMode]
/// is passed straight through to [MaterialApp.router]'s `themeMode`, which
/// already knows how to resolve [ThemeMode.system] against the platform
/// brightness on its own, so there is no need to duplicate that resolution
/// here.
class App extends StatefulWidget {
  /// Creates the root widget.
  ///
  /// [themeModeController] can be supplied by a caller (mainly tests) that
  /// wants to control or observe the theme mode from the outside; when
  /// omitted, the widget owns its own controller and disposes it.
  App({super.key, ThemeModeController? themeModeController})
      : themeModeController = themeModeController ?? ThemeModeController(),
        _ownsController = themeModeController == null;

  /// Tracks the user's manual theme override, defaulting to "follow system".
  final ThemeModeController themeModeController;

  /// Whether this widget created [themeModeController] itself, and is
  /// therefore responsible for disposing it.
  ///
  /// A controller passed in by a caller is presumed to still be owned by
  /// that caller and must not be disposed here.
  final bool _ownsController;

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
  void didUpdateWidget(covariant App oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeModeController != widget.themeModeController) {
      oldWidget.themeModeController.removeListener(_onThemeModeChanged);
      widget.themeModeController.addListener(_onThemeModeChanged);
    }
  }

  @override
  void dispose() {
    widget.themeModeController.removeListener(_onThemeModeChanged);
    if (widget._ownsController) {
      widget.themeModeController.dispose();
    }
    super.dispose();
  }

  void _onThemeModeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SocialFeed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeModeController.mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: getIt<GoRouter>(),
      builder: (context, routedChild) {
        return Column(
          children: [
            const ConnectivityAwareOfflineBanner(),
            Expanded(child: routedChild ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
