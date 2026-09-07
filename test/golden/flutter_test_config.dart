import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';

/// Runs before every test in this directory tree, golden or not.
///
/// Golden tests render text with Flutter's real fonts by default in `flutter
/// test`, but only after they have been explicitly loaded; without this,
/// every golden would render with the "Ahem" placeholder test font instead
/// (a font that draws every glyph as a solid block), producing reference
/// images that look nothing like what a device actually shows.
/// [loadAppFonts] pulls in both the Material icon font and this app's own
/// bundled fonts so goldens are representative.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}
