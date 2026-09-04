import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../repositories/auth_repository.dart';

/// Signs the current user out locally, and best-effort invalidates the
/// session on the server.
///
/// Reads the stored refresh token and, if one exists, calls
/// `AuthRepository.logout` with it so the backend can invalidate it
/// server-side per the Auth Model. `SecureTokenStorage.clearTokens` always
/// runs afterwards, regardless of whether that call found a token, and
/// regardless of whether the call succeeded or failed, since local sign-out
/// should never be blocked by a network problem it has no control over.
class SignOutUseCase {
  // A `required this._authRepository` named parameter is still callable as
  // `SignOutUseCase(authRepository: ...)` from outside this file; Dart
  // exposes the public name at the call site even though the field itself
  // stays private, the same pattern already used by `SyncService`.
  SignOutUseCase({
    required this._authRepository,
    required this._tokenStorage,
  });

  final AuthRepository _authRepository;
  final SecureTokenStorage _tokenStorage;

  /// Clears the local session unconditionally.
  ///
  /// Judgment call: sign-out never surfaces as a failure to the caller,
  /// even if the server-side `POST /auth/logout` call fails or cannot be
  /// made at all (no connectivity, no stored refresh token). The local
  /// tokens are wiped either way, so from the user's point of view they are
  /// signed out the moment they tap the button; a stray, unreachable
  /// refresh token left behind on the server is a minor inconsistency the
  /// backend already tolerates (it simply expires on its own), not
  /// something worth blocking the UI or showing an error for. Always
  /// returning `Right` keeps `AuthStore.signOut` a simple, unconditional
  /// `@action` that clears `currentUser` without needing to reason about a
  /// failure branch for what is, locally, an operation that cannot fail.
  Future<Either<Failure, void>> call() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken != null) {
      await _authRepository.logout(refreshToken);
    }

    await _tokenStorage.clearTokens();

    return const Right(null);
  }
}
