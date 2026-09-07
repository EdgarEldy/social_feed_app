import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart' hide Listenable;

import '../../features/auth/presentation/stores/auth_store.dart';

/// Bridges [AuthStore]'s MobX-observable `isAuthenticated` to a
/// [Listenable], so it can be handed to `go_router`'s `refreshListenable`.
///
/// `go_router` only re-runs its `redirect` callback on a navigation event or
/// when the `Listenable` passed as `refreshListenable` fires
/// `notifyListeners()`. `AuthStore.isAuthenticated` is a MobX `@computed`,
/// not a `ChangeNotifier`, so without this adapter a sign in/out that
/// happens without a separate navigation (tapping "sign out" on the profile
/// tab, for instance) would leave the router showing a screen that no
/// longer matches the auth state until some unrelated navigation happened
/// to trigger the guard again.
///
/// A MobX `reaction` watches [AuthStore.isAuthenticated] and calls
/// [notifyListeners] every time its value changes, which is exactly the
/// signal `go_router` needs to re-run the redirect guard immediately.
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(AuthStore authStore) {
    _disposeReaction = reaction<bool>(
      (_) => authStore.isAuthenticated,
      (_) => notifyListeners(),
    );
  }

  late final ReactionDisposer _disposeReaction;

  @override
  void dispose() {
    _disposeReaction();
    super.dispose();
  }
}
