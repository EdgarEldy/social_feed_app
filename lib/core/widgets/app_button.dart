import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

/// The app's standard primary button.
///
/// Wraps [FilledButton] (the Material 3 successor to [ElevatedButton] for
/// high-emphasis actions) with this app's spacing and radius tokens applied
/// consistently, so no screen hand-rolls its own button padding or corner
/// radius.
class AppButton extends StatelessWidget {
  /// Creates a primary button showing [label], calling [onPressed] when
  /// tapped. Pass null to render it disabled.
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// The button's visible text.
  final String label;

  /// Called when the button is tapped. Null renders the button disabled.
  final VoidCallback? onPressed;

  /// An optional leading icon shown before [label].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingLg,
        vertical: AppDimens.spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
