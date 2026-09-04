import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../stores/auth_store.dart';

/// Shows a [SnackBar] every time [authStore]'s `lastError` transitions from
/// `null` to a non-null [Failure], wrapping [child] without altering it.
///
/// `AuthStore` clears `lastError` to `null` at the start of every
/// `signUp`/`signIn`/`signOut` call and only sets it again if that call
/// fails, so a MobX `reaction` on `lastError` fires exactly once per failed
/// attempt: once when it flips from `null` to a `Failure` on that attempt.
/// A plain `Observer` rebuilding on every read of `lastError` would instead
/// re-run its builder (and, naively, re-show the `SnackBar`) on every
/// unrelated rebuild that happens to read the same still-set value, so a
/// `reaction`, which only fires when the observed value actually changes, is
/// the correct tool here rather than an `Observer`.
class AuthErrorListener extends StatefulWidget {
  /// Creates a listener that watches [authStore] and wraps [child].
  const AuthErrorListener({
    super.key,
    required this.authStore,
    required this.child,
  });

  /// The store whose `lastError` is observed.
  final AuthStore authStore;

  /// The subtree rendered underneath, unaffected by the listener itself.
  final Widget child;

  @override
  State<AuthErrorListener> createState() => _AuthErrorListenerState();
}

class _AuthErrorListenerState extends State<AuthErrorListener> {
  late final ReactionDisposer _disposeReaction;

  @override
  void initState() {
    super.initState();
    _disposeReaction = reaction<Failure?>(
      (_) => widget.authStore.lastError,
      (failure) {
        if (failure == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  void dispose() {
    _disposeReaction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
