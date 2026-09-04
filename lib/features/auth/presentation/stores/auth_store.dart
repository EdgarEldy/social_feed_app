import 'package:fpdart/fpdart.dart' show Either;
import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

part 'auth_store.g.dart';

/// Holds the app's current authentication state and drives the sign
/// up/in/out flows behind an `Observer`.
///
/// This is a long-lived singleton, registered in `get_it` the same way
/// `ConnectivityStore` is: authentication is a cross-cutting concern that
/// both the `go_router` redirect guard and every authenticated page need to
/// read, so a single shared instance is simpler than threading one through
/// every widget that cares about it.
///
/// ## Session restoration interpretation
///
/// The [Auth Model](../../../../../README.md) says session restoration on
/// app start should "read the stored tokens; if present and valid, restore
/// the authenticated state without a fresh login." The API Contract has no
/// `GET /users/me` (or equivalent) endpoint to validate a token against and
/// fetch a full `User` profile, and `SecureTokenStorage` only ever holds the
/// two raw token strings, never a cached `User`. That rules out the
/// "obviously correct" implementation (call an endpoint, get a `User` back)
/// because that endpoint does not exist in this contract, and rules out
/// decoding the JWT payload to fabricate a `User`, because a JWT's claims
/// are not specified anywhere in the API Contract; guessing at claim names
/// (`sub`, `email`, ...) to synthesize `displayName`/`photoUrl`/`createdAt`
/// would be inventing data the client has no right to assume exists.
///
/// This store instead treats "an access token exists in secure storage" as
/// sufficient to provisionally restore the *authenticated* state, without
/// pretending to also have restored the *user profile*. Concretely:
/// [hasStoredSession] flips to `true` when [restoreSession] finds a stored
/// access token, and [isAuthenticated] is `true` whenever either
/// [hasStoredSession] or [currentUser] says so. [currentUser] itself stays
/// `null` until a real sign in/up response, or a later screen that loads the
/// user's own profile (`feature/users`), actually populates it.
///
/// The tradeoff: [isAuthenticated] can briefly be `true` for a token that
/// has since expired or been revoked server-side. That is an acceptable gap
/// here because `AuthInterceptor` already exists to close it at the network
/// layer: the very first authenticated request made after a stale
/// restoration attaches the (now invalid) access token, gets a `401`, tries
/// a silent refresh, and clears the stored tokens if that refresh also
/// fails. `go_router`'s redirect guard (the next task in this branch) only
/// needs a same-frame answer to "should this user see `/login`?", it does
/// not need proof the token is still good server-side, that proof arrives
/// (or does not) on the first real API call regardless.
///
/// The alternative considered and rejected: leaving [isAuthenticated] tied
/// only to `currentUser != null` and not restoring anything on app start.
/// That would force every app restart to bounce a still-logged-in user back
/// to `/login`, defeating the entire point of persisting tokens in
/// `SecureTokenStorage` in the first place.
class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  _AuthStore({
    required this._signUpUseCase,
    required this._signInUseCase,
    required this._signOutUseCase,
    required this._tokenStorage,
  });

  final SignUpUseCase _signUpUseCase;
  final SignInUseCase _signInUseCase;
  final SignOutUseCase _signOutUseCase;
  final SecureTokenStorage _tokenStorage;

  /// The signed-in user's profile, once known.
  ///
  /// Populated by a successful [signUp]/[signIn] response. Deliberately
  /// *not* populated by [restoreSession], see the class doc above; it stays
  /// `null` after a restored session until something else (a sign in/up, or
  /// a future "load my profile" call from `feature/users`) supplies a real
  /// `User`.
  @observable
  User? currentUser;

  /// Whether [restoreSession] found a stored access token on this app
  /// start.
  ///
  /// This is what lets [isAuthenticated] become `true` on a restored
  /// session even though [currentUser] is still `null`; see the class doc
  /// for why the client cannot do better than this without an endpoint the
  /// API Contract does not define. Cleared alongside [currentUser] by
  /// [signOut] and by [forceSignOut].
  @observable
  bool hasStoredSession = false;

  /// Whether [restoreSession] is still in flight.
  ///
  /// Exposed so a splash/root widget can, if it wants to, hold off on the
  /// first `go_router` redirect decision until the one-shot secure storage
  /// read actually completes, rather than briefly redirecting to `/login`
  /// on every cold start.
  @observable
  bool isRestoringSession = false;

  /// Whether a sign up/in/out call is currently in flight.
  ///
  /// Lets `LoginPage`/`RegisterPage` disable their submit button and show a
  /// spinner instead of duplicating that bookkeeping with local
  /// `StatefulWidget` state.
  @observable
  bool isSubmitting = false;

  /// The failure from the most recent sign up/in/out attempt, or `null`.
  ///
  /// Cleared at the start of every [signUp]/[signIn]/[signOut] call so a
  /// stale error never lingers into the next attempt. Task 9 of this branch
  /// (surfacing API errors as a `SnackBar`) reads this from an `Observer`
  /// and shows [Failure.message] when it changes.
  @observable
  Failure? lastError;

  /// Whether the app currently considers the user signed in.
  ///
  /// `true` if either a real `User` is known ([currentUser]) or a stored
  /// session was restored ([hasStoredSession]); see the class doc for why
  /// the latter exists. This is what the `go_router` redirect guard reads.
  @computed
  bool get isAuthenticated => currentUser != null || hasStoredSession;

  /// Reads the stored access token and, if one exists, provisionally
  /// restores the authenticated state.
  ///
  /// Called once at app start, after `configureDependencies()` and before
  /// `runApp`, so `go_router`'s initial redirect decision already sees the
  /// right [isAuthenticated] value. See the class doc for exactly what
  /// "restore" means here and why.
  @action
  Future<void> restoreSession() async {
    isRestoringSession = true;
    try {
      final accessToken = await _tokenStorage.getAccessToken();
      hasStoredSession = accessToken != null;
    } finally {
      isRestoringSession = false;
    }
  }

  /// Registers a new account via `POST /auth/register` and, on success,
  /// signs the user straight in.
  @action
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    lastError = null;
    isSubmitting = true;
    final result = await _signUpUseCase(
      email: email,
      password: password,
      displayName: displayName,
    );
    _applyAuthResult(result);
    isSubmitting = false;
  }

  /// Signs an existing user in via `POST /auth/login`.
  @action
  Future<void> signIn({required String email, required String password}) async {
    lastError = null;
    isSubmitting = true;
    final result = await _signInUseCase(email: email, password: password);
    _applyAuthResult(result);
    isSubmitting = false;
  }

  /// Signs the current user out, clearing both the stored tokens and the
  /// in-memory session state.
  ///
  /// `SignOutUseCase` always resolves to `Right(null)` by design (see its
  /// doc comment), so the `Left` branch below is unreachable in practice
  /// today; it is still handled rather than assumed away, since a future
  /// change to that usecase should not silently start dropping failures on
  /// the floor here.
  @action
  Future<void> signOut() async {
    lastError = null;
    isSubmitting = true;
    final result = await _signOutUseCase();
    result.match((failure) => lastError = failure, (_) => _clearSession());
    isSubmitting = false;
  }

  /// Clears the in-memory session without touching stored tokens or calling
  /// the sign-out usecase.
  ///
  /// Not wired up to anything yet on this task; it exists for
  /// `AuthInterceptor`'s forced-logout path (see its class doc: "the
  /// original 401 propagates so the caller ... can react to a forced
  /// sign-out"), where the tokens are already cleared by the interceptor
  /// itself and only the in-memory store still needs to catch up.
  @action
  void forceSignOut() {
    lastError = null;
    _clearSession();
  }

  @action
  void _applyAuthResult(Either<Failure, User> result) {
    result.match(
      (failure) => lastError = failure,
      (user) {
        currentUser = user;
        hasStoredSession = true;
      },
    );
  }

  @action
  void _clearSession() {
    currentUser = null;
    hasStoredSession = false;
  }
}
