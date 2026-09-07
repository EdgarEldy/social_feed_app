import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import 'session_persistence.dart';

/// Signs a user in via `POST /auth/google` and turns the stateless
/// `AuthRepository` result into the persisted session `AuthStore` needs.
///
/// Same bridge role as `SignInUseCase`, but exchanging a Google ID token
/// instead of an email/password pair: on success it persists the returned
/// `accessToken`/`refreshToken` pair via `SecureTokenStorage` and returns
/// just the `User`, so `AuthStore` never has to see a raw token. The
/// persist-then-unwrap step is shared with `SignInUseCase`/`SignUpUseCase`
/// via `persistSessionAndReturnUser`, so this maps a successful response the
/// exact same way those two already do.
///
/// If the given Google account's email is already registered under a
/// password-based account, the server's own conflict response passes
/// through unchanged as a `Left`, exactly like any other auth failure; this
/// usecase does not special-case that response or attempt to merge accounts
/// itself.
class SignInWithGoogleUseCase {
  SignInWithGoogleUseCase({
    required this._authRepository,
    required this._tokenStorage,
  });

  final AuthRepository _authRepository;
  final SecureTokenStorage _tokenStorage;

  /// Calls `POST /auth/google` with [idToken], persists the returned tokens
  /// on success, and returns the signed-in `User`. A failed request is
  /// passed through unchanged as a `Left`.
  Future<Either<Failure, User>> call({required String idToken}) async {
    final result = await _authRepository.signInWithGoogle(idToken);

    return result.match(
      (failure) async => Left(failure),
      (session) => persistSessionAndReturnUser(session, _tokenStorage),
    );
  }
}
