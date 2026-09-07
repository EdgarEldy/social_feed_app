import 'package:flutter/material.dart';

/// Holds the user's manual theme preference, defaulting to following the
/// operating system's brightness setting.
///
/// This is UI-local, ephemeral state (nothing else in the app needs to read
/// or react to it, and it does not need to survive an app restart), so a
/// plain [ChangeNotifier] is enough. MobX stores, wired through `get_it`,
/// are reserved for state that is part of the app's actual domain, starting
/// with `AuthStore` in `feature/auth`.
class ThemeModeController extends ChangeNotifier {
  /// Creates a controller, defaulting to [ThemeMode.system] unless
  /// [initialMode] overrides it (mainly useful for tests).
  ThemeModeController({ThemeMode initialMode = ThemeMode.system})
      : _mode = initialMode;

  ThemeMode _mode;

  /// The currently selected theme mode.
  ///
  /// [ThemeMode.system] is the default and means "follow the OS setting".
  /// [ThemeMode.light]/[ThemeMode.dark] are explicit overrides chosen by
  /// the user, taking precedence over the OS setting until changed again.
  ThemeMode get mode => _mode;

  /// Updates the manual override and notifies listeners so the widgets
  /// reading this controller rebuild with the new theme.
  void setThemeMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
