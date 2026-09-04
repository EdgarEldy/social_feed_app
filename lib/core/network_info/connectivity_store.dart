import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobx/mobx.dart';

part 'connectivity_store.g.dart';

/// Tracks the device's current network connectivity as an observable flag.
///
/// This is a long-lived singleton (registered in `get_it`) rather than a
/// per-screen store: connectivity is a cross-cutting concern that both the
/// `OfflineBanner` and every offline-first repository need to read, so a
/// single shared instance is simpler than plumbing a stream through every
/// layer that cares about it.
class ConnectivityStore = _ConnectivityStore with _$ConnectivityStore;

abstract class _ConnectivityStore with Store {
  _ConnectivityStore({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Whether the device currently has network connectivity.
  ///
  /// Starts `true` so the app does not flash an offline banner before the
  /// first real check completes; [_init] corrects this immediately after
  /// construction if the device actually starts out offline.
  @observable
  bool isOnline = true;

  /// Runs the initial connectivity check and starts listening for changes.
  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
    );
  }

  @action
  void _updateStatus(List<ConnectivityResult> results) {
    isOnline = results.any((result) => result != ConnectivityResult.none);
  }

  /// Cancels the connectivity subscription.
  ///
  /// Must be called when this store is torn down (its `get_it` `dispose:`
  /// callback) so the stream listener does not outlive the app.
  void dispose() {
    _subscription?.cancel();
  }
}
