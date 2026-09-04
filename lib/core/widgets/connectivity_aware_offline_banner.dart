import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../di/injection_container.dart';
import '../network_info/connectivity_store.dart';
import 'offline_banner.dart';

/// Connects the presentational [OfflineBanner] to real connectivity state.
///
/// [OfflineBanner] itself stays a plain [StatelessWidget] with no
/// `get_it`/MobX awareness, per its own scope from `feature/design-system`.
/// This wrapper is the seam that resolves the singleton [ConnectivityStore]
/// from `get_it` and rebuilds only the banner, via [Observer], whenever
/// `isOnline` changes; nothing else in the widget tree re-renders because of
/// a connectivity change.
class ConnectivityAwareOfflineBanner extends StatelessWidget {
  /// Creates the connectivity-aware wrapper around [OfflineBanner].
  const ConnectivityAwareOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityStore = getIt<ConnectivityStore>();

    return Observer(
      builder: (_) => OfflineBanner(isOffline: !connectivityStore.isOnline),
    );
  }
}
