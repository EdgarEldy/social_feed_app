import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

/// The app's standard content card.
///
/// Wraps [Card] with this app's padding and corner radius tokens applied
/// consistently, so post cards, profile summaries, and any other card-like
/// surface share the same shape and internal spacing by default.
class AppCard extends StatelessWidget {
  /// Creates a card wrapping [child], with consistent padding and radius.
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.spacingMd),
    this.onTap,
  });

  /// The card's content.
  final Widget child;

  /// The padding applied around [child], inside the card's border.
  final EdgeInsetsGeometry padding;

  /// Called when the card is tapped. When null, the card is not tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
