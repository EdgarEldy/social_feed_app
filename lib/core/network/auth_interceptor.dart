import 'package:dio/dio.dart';

import '../storage/secure_token_storage.dart';
import 'api_endpoints.dart';

/// Attaches the current access token to outgoing requests and handles a
/// `401` response by attempting a silent refresh before retrying the
/// original request once.
///
/// When the refresh attempt cannot even be made (no stored refresh token),
/// is made and itself fails, or the retried request comes back `401` again
/// even after an apparently successful refresh, this interceptor tags the
/// propagating [DioException] with `extra['sessionExpired'] = true` before
/// handing it back to `dio`, but only if the original request was actually
/// authenticated in the first place (it carried an `Authorization` header).
/// That tag is how `dio_exception_mapper.dart` tells a genuinely expired
/// session apart from a first-attempt `401`, such as a wrong password on
/// `POST /auth/login`. That case can reach this same "no refresh token"
/// branch (a fresh install has neither an access nor a refresh token
/// stored), but must not be tagged as `sessionExpired` since there was
/// never a session to expire. The same three spots also invoke
/// [_onSessionExpired], if one was supplied, so the app's `AuthStore` can
/// clear its in-memory session the moment a forced sign-out happens.
///
/// This interceptor is attached to the single intercepted [Dio] instance
/// (`getIt<Dio>()`) that every remote datasource in the app shares. That
/// creates a well-known footgun: if the `POST /auth/refresh` call made
/// inside [onError] went through that same intercepted instance, it would
/// re-enter [onRequest] (attaching a stale bearer token to a request whose
/// body is the refresh token, not an access token) and could re-enter
/// [onError] again if the refresh call itself ever came back `401`,
/// recursing indefinitely. To avoid this, the refresh call is made through
/// [_refreshDio], a small standalone [Dio] instance built once in the
/// constructor with no interceptors of its own. The retry of the *original*
/// request, on the other hand, deliberately does go through the intercepted
/// [_dio] instance passed in by [DioClient.create], since that is a fresh,
/// unrelated request and gets the benefit of the logger/interceptor chain.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._dio,
    this._tokenStorage, {
    required String baseUrl,
    void Function(String? expiredAccessToken)? onSessionExpired,
  }) : _refreshDio = Dio(BaseOptions(baseUrl: baseUrl)),
       // Deliberately not `this._onSessionExpired`: that would make the
       // named parameter itself private (`_onSessionExpired`), which
       // callers outside this library (e.g. DioClient.create) could not
       // pass a value for at all.
       // ignore: prefer_initializing_formals
       _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  /// Notified, if supplied, the moment a request that was actually
  /// authenticated ([wasAuthenticatedRequest]) is tagged as
  /// `sessionExpired` below, i.e. exactly when `AuthStore.forceSignOut()`
  /// (wired up at the `get_it` composition root) should run.
  ///
  /// The argument is the access token that was in [_tokenStorage]
  /// immediately before this method clears it, captured up front in
  /// [onError] before any of the branches below call
  /// `_tokenStorage.clearTokens()`. `AuthStore.forceSignOut()` needs that
  /// value, not the (by-then empty) stored one, to best-effort deregister
  /// this device's push token: `DELETE /devices/:pushToken` is an
  /// authenticated endpoint, and by the time `_onSessionExpired` fires,
  /// [onRequest] would otherwise have nothing left to attach.
  ///
  /// This is a callback rather than a direct `AuthStore` dependency because
  /// [AuthInterceptor] is constructed inside [DioClient.create], and
  /// `AuthStore` transitively depends on that same [Dio] instance (through
  /// `AuthRepository`/`AuthRemoteDatasource`). Taking `AuthStore` directly
  /// here would be a circular dependency at construction time; a callback
  /// resolved lazily, only when it actually fires, breaks that cycle.
  final void Function(String? expiredAccessToken)? _onSessionExpired;

  /// A bare, non-intercepted client used solely for `POST /auth/refresh`.
  /// See the class doc for why this cannot be [_dio].
  final Dio _refreshDio;

  /// Marks a request's [RequestOptions.extra] so a retried request that
  /// comes back `401` a second time is not retried again, guaranteeing "at
  /// most one retry" even if the refreshed token is somehow still rejected.
  static const _retriedKey = 'authInterceptorRetried';

  /// Marks a request's [RequestOptions.extra] to record that its `401` is
  /// specifically a "session expired" case: the original request carried an
  /// `Authorization` header (so a session existed), and either there was no
  /// refresh token to attempt a silent refresh with, or the
  /// `POST /auth/refresh` call itself failed. Checking for the header is
  /// what tells this apart from a plain first-attempt `401` with no prior
  /// session at all, such as a wrong password on login: that request also
  /// has no refresh token stored, but it never had an access token attached
  /// either, so it must not be tagged as an expired session.
  /// `mapDioExceptionToFailure` in `dio_exception_mapper.dart` reads this
  /// flag to decide between an `UnauthorizedFailure` and the generic
  /// `ServerFailure` used for every other status code.
  static const _sessionExpiredKey = 'sessionExpired';

  /// Coalesces concurrent refresh attempts. If several requests fail with
  /// `401` around the same time (e.g. a burst of feed/comments calls), they
  /// all await the same in-flight refresh instead of each calling
  /// `/auth/refresh` separately.
  Future<({bool refreshed, String? expiredAccessToken})>? _pendingRefresh;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;

    if (!isUnauthorized) {
      handler.next(err);
      return;
    }

    // A 401 only means "the session expired" if the original request was
    // actually authenticated to begin with, i.e. onRequest attached an
    // Authorization header because a stored access token existed at the
    // time. A request that never carried one (a wrong-password
    // POST /auth/login on a fresh install, where no session exists yet) is
    // a plain credentials failure, not an expired session, even though the
    // status code is the same 401 and the user may also have no refresh
    // token stored. Without this check that case would be mis-tagged as
    // sessionExpired below and mapped to UnauthorizedFailure instead of the
    // generic ServerFailure the wrong-credentials case should get.
    final wasAuthenticatedRequest = err.requestOptions.headers.containsKey(
      'Authorization',
    );

    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (alreadyRetried) {
      // This is the retried request itself coming back 401 a second time:
      // the refresh appeared to succeed (a new access token was stored and
      // attached), but the session is genuinely dead regardless, whether
      // the new token is somehow still rejected or expired again
      // immediately. That still needs to be tagged and signed out exactly
      // like a failed refresh below; the only difference is that no further
      // refresh or retry is attempted here, since _retriedKey already
      // guarantees at most one retry.
      //
      // The access token is read before clearTokens() below, not after, so
      // _onSessionExpired can still hand AuthStore.forceSignOut() the token
      // that was valid immediately before this session was invalidated;
      // see _onSessionExpired's doc for why that matters for the
      // push-token deregistration call it makes. Read lazily here (and in
      // the two branches below), rather than once unconditionally at the
      // top of this method, so the common case of a 401 that a successful
      // refresh-and-retry resolves does not pay for a call that branch
      // never actually uses.
      final expiredAccessToken = await _tokenStorage.getAccessToken();
      await _tokenStorage.clearTokens();
      if (wasAuthenticatedRequest) {
        err.requestOptions.extra[_sessionExpiredKey] = true;
        _onSessionExpired?.call(expiredAccessToken);
      }
      handler.next(err);
      return;
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      // Nothing to refresh with. Only treat this as a lost session if the
      // request had a session to lose in the first place.
      final expiredAccessToken = await _tokenStorage.getAccessToken();
      await _tokenStorage.clearTokens();
      if (wasAuthenticatedRequest) {
        err.requestOptions.extra[_sessionExpiredKey] = true;
        _onSessionExpired?.call(expiredAccessToken);
      }
      handler.next(err);
      return;
    }

    final refreshResult = await _refreshAccessToken(refreshToken);
    if (!refreshResult.refreshed) {
      // _refreshAccessToken already cleared the tokens on failure, so the
      // access token has to be read before calling it, not after (unlike
      // the two branches above, where clearTokens() happens right here).
      // The original 401 propagates, and _onSessionExpired fires so
      // AuthStore (wired up at the get_it composition root) can react to a
      // forced sign-out.
      //
      // In practice this branch is only reachable for a previously
      // authenticated request: saveTokens/clearTokens in
      // SecureTokenStorage always write and delete the access and refresh
      // tokens together, so a non-null refreshToken here means the access
      // token was also present in storage (and therefore attached by
      // onRequest) when the original request went out. The header check is
      // kept anyway rather than relied-on-by-inference, so this branch does
      // not silently depend on that storage invariant holding forever.
      if (wasAuthenticatedRequest) {
        err.requestOptions.extra[_sessionExpiredKey] = true;
        _onSessionExpired?.call(refreshResult.expiredAccessToken);
      }
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra[_retriedKey] = true;
      // The new access token is already in secure storage at this point, so
      // going through the intercepted _dio lets onRequest attach it exactly
      // like it would for any other call.
      final retryResponse = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Performs the refresh, or joins an already in-flight one.
  ///
  /// Returns the outcome as a record rather than a bare `bool` and a
  /// separate field: several `onError` invocations can coalesce onto the
  /// same in-flight refresh (see [_pendingRefresh]'s doc), and a later,
  /// independent refresh can start as soon as this one completes and
  /// `_pendingRefresh` resets to `null`. A shared mutable field holding
  /// "the last failed refresh's expired token" would be a race between
  /// that later refresh overwriting it and an earlier waiter reading it;
  /// returning the token as part of the same `Future` each caller already
  /// awaits ties it to the specific refresh attempt they were actually
  /// waiting on, so there is nothing left to race.
  Future<({bool refreshed, String? expiredAccessToken})> _refreshAccessToken(
    String refreshToken,
  ) {
    return _pendingRefresh ??= _performRefresh(refreshToken).whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<({bool refreshed, String? expiredAccessToken})> _performRefresh(
    String refreshToken,
  ) async {
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      final newAccessToken = response.data!['accessToken'] as String;
      // POST /auth/refresh only returns a new accessToken per the API
      // Contract, so the existing refreshToken is kept as-is.
      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );
      return (refreshed: true, expiredAccessToken: null);
    } on DioException {
      return (refreshed: false, expiredAccessToken: await _clearTokensAfterFailedRefresh());
    } catch (_) {
      // A refresh response that comes back 2xx but does not actually match
      // the documented `{ accessToken }` shape (missing key, wrong type)
      // throws a TypeError from the cast above, not a DioException. TypeError
      // is a subtype of Error, not Exception, so `on Exception catch` would
      // silently miss it and let it escape uncaught. A malformed refresh
      // body is treated the same as a failed refresh: clear the tokens and
      // report failure.
      return (refreshed: false, expiredAccessToken: await _clearTokensAfterFailedRefresh());
    }
  }

  /// Reads the access token in storage immediately before clearing it, so
  /// the caller can still hand it to `_onSessionExpired` afterward.
  Future<String?> _clearTokensAfterFailedRefresh() async {
    final expiredAccessToken = await _tokenStorage.getAccessToken();
    await _tokenStorage.clearTokens();
    return expiredAccessToken;
  }
}
