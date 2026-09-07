import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import 'session_persistence.dart';

/// Signs an existing user in and turns the stateless `AuthRepository` result
/// into the persisted session `AuthStore` (task 7) actually needs.
///
/// Same bridge role as `SignUpUseCase`, but calling `POST /auth/login`
/// instead of `POST /auth/register`: on success it persists the returned
/// `accessToken`/`refreshToken` pair via `SecureTokenStorage` and returns
/// just the `User`, so `AuthStore` never has to see a raw token. The actual
/// persist-then-unwrap step is shared with `SignUpUseCase` via
/// `persistSessionAndReturnUser`.
class SignInUseCase {
  // A `required this._authRepository` named parameter is still callable as
  // `SignInUseCase(authRepository: ...)` from outside this file; Dart
  // exposes the public name at the call site even though the field itself
  // stays private, the same pattern already used by `SyncService`.
  SignInUseCase({
    required this._authRepository,
    required this._tokenStorage,
  });

  final AuthRepository _authRepository;
  final SecureTokenStorage _tokenStorage;

  /// Calls `POST /auth/login` with the given credentials, persists the
  /// returned tokens on success, and returns the signed-in `User`. A failed
  /// request is passed through unchanged as a `Left`.
  Future<Either<Failure, User>> call({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.login(
      email: email,
      password: password,
    );

    return result.match(
      (failure) async => Left(failure),
      (session) => persistSessionAndReturnUser(session, _tokenStorage),
    );
  }
}
