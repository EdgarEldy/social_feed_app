import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../entities/auth_session.dart';

/// Contract for the authentication endpoints in the API Contract:
/// `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh` and
/// `POST /auth/logout`.
///
/// This repository is deliberately stateless in both directions: it never
/// reads from or writes to `SecureTokenStorage` itself. On register and
/// login it hands the tokens it received from the API straight back to the
/// caller instead of persisting them; on refresh and logout the caller
/// passes in whatever refresh token it already has rather than this
/// interface reading one internally. Deciding where, whether, and when to
/// persist tokens is entirely the job of the usecases (and the `dio` auth
/// interceptor) built in `feature/auth`. The implementation in
/// `data/repositories/auth_repository_impl.dart` is a pure HTTP-boundary
/// translation with no dependency on token storage at all.
///
/// `POST /auth/google` is deliberately not declared here: it belongs to the
/// `feature/integrations` bonus branch, which is expected to extend this
/// interface (or add a sibling method) once that branch starts.
abstract class AuthRepository {
  /// Calls `POST /auth/register` with `{ email, password, displayName }`.
  ///
  /// Returns the created `user` together with the `accessToken` and
  /// `refreshToken` from the response, as an `AuthSession` (replacing the
  /// anonymous record this used to spell out separately on [register] and
  /// [login]), so the calling usecase can decide how to persist them.
  Future<Either<Failure, AuthSession>> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Calls `POST /auth/login` with `{ email, password }`.
  ///
  /// Returns the authenticated `user` together with the `accessToken` and
  /// `refreshToken` from the response, for the same reason as [register].
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  /// Calls `POST /auth/refresh` with `{ refreshToken }`.
  ///
  /// [refreshToken] is passed in explicitly by the caller rather than read
  /// internally, so this repository stays stateless and has no dependency
  /// on token storage; reading the currently stored refresh token before
  /// calling this method is the responsibility of the usecase (or the
  /// `dio` auth interceptor) built in `feature/auth`.
  ///
  /// Returns the new `accessToken` from the response so the caller can
  /// persist it; this repository does not write to token storage itself.
  Future<Either<Failure, String>> refresh(String refreshToken);

  /// Calls `POST /auth/logout` with `{ refreshToken }`, expecting
  /// `204 No Content`.
  ///
  /// [refreshToken] is passed in explicitly by the caller for the same
  /// reason as in [refresh]: this repository does not read token storage
  /// itself.
  Future<Either<Failure, void>> logout(String refreshToken);
}
