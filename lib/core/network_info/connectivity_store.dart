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
  ///
  /// This runs unawaited from the constructor, so any exception it throws
  /// would otherwise become an unhandled async error and, worse, would leave
  /// [isOnline] stuck at its `true` default forever if the initial check is
  /// what failed. Both steps are guarded so that a platform failure on the
  /// one-shot [Connectivity.checkConnectivity] call still lets the ongoing
  /// [Connectivity.onConnectivityChanged] subscription start, which is what
  /// eventually corrects [isOnline] once a real connectivity change fires.
  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
    } catch (_) {
      // Leave `isOnline` at its current value rather than guessing. The
      // subscription started below is still our best chance at getting a
      // correct value soon.
    }

    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateStatus,
      );
    } catch (_) {
      // If even subscribing throws, there is nothing further this store can
      // do; `isOnline` simply keeps whatever value it last had.
    }
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
