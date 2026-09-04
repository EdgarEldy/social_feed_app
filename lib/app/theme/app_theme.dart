import 'package:flutter/material.dart';

/// Central definition of the app's Material 3 light and dark themes.
///
/// Both themes are generated from a single seed color via
/// [ColorScheme.fromSeed], the Material 3 way of deriving a full, harmonious
/// tonal palette (primary, secondary, tertiary, surface, and so on) from one
/// brand color instead of hand-picking every shade individually.
abstract final class AppTheme {
  const AppTheme._();

  /// Brand seed color the whole palette is generated from.
  ///
  /// A saturated blue reads as approachable and trustworthy, a reasonable
  /// choice for a social feed app where the feed itself, not the chrome,
  /// should carry most of the visual interest.
  static const Color _seedColor = Color(0xFF3D5AFE);

  /// The light theme, used whenever the app's effective brightness resolves
  /// to [Brightness.light].
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
  );

  /// The dark theme, used whenever the app's effective brightness resolves
  /// to [Brightness.dark].
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
