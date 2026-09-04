import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

/// A centered error state: an icon, a message, and an optional retry action.
///
/// Used across the app wherever a store's async state resolves to an error
/// (a failed network request, a cache read failure, and so on), so every
/// screen presents errors consistently instead of each screen inventing its
/// own layout.
///
/// ## Semantics convention for icon-only buttons
///
/// [retry] renders as an icon-only [IconButton] (no visible text label), so
/// it always carries an explicit `tooltip`. This is the convention every
/// icon-only affordance added to a shared widget in this app should follow:
/// give it either a `tooltip` (for an [IconButton]) or an explicit
/// [Semantics] `label` (for a bare [GestureDetector]/[InkWell]), so screen
/// readers have something to announce in place of the missing visible text.
class ErrorView extends StatelessWidget {
  /// Creates an error view showing [message], with an optional [onRetry]
  /// callback that renders a retry action when provided.
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// The error message shown to the user.
  final String message;

  /// Called when the user taps the retry action. When null, no retry action
  /// is rendered.
  final VoidCallback? onRetry;

  /// The icon shown above [message].
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimens.spacingXxl,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppDimens.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimens.spacingSm),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
