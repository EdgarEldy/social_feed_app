import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

/// A thin banner shown at the top of a screen while the device is offline.
///
/// This branch (`feature/design-system`) only builds the presentational
/// widget, driven by the plain [isOffline] flag passed in. `feature/offline-and-sync`
/// wires it up to real connectivity state, wrapping it in an [Observer]
/// watching `ConnectivityStore.isOnline` so it appears and disappears
/// automatically as the device's network status changes.
class OfflineBanner extends StatelessWidget {
  /// Creates an offline banner, visible only when [isOffline] is true.
  const OfflineBanner({super.key, required this.isOffline});

  /// Whether the device is currently considered offline.
  ///
  /// When false, this widget renders nothing ([SizedBox.shrink]).
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: AppDimens.spacingMd,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Flexible(
            child: Text(
              "You're offline. Showing cached data.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
