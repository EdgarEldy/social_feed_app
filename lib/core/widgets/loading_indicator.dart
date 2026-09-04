import 'package:flutter/material.dart';

/// A centered, app-wide loading spinner.
///
/// A thin wrapper around [CircularProgressIndicator] so every screen shows
/// the same loading affordance instead of each screen centering its own
/// spinner ad hoc.
class LoadingIndicator extends StatelessWidget {
  /// Creates a centered loading indicator.
  const LoadingIndicator({super.key, this.semanticsLabel});

  /// Announced by screen readers while the indicator is visible. Defaults to
  /// a generic "Loading" label when omitted.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        semanticsLabel: semanticsLabel ?? 'Loading',
      ),
    );
  }
}
