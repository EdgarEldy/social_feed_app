import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Registers a new account and turns the stateless `AuthRepository` result
/// into the persisted session `AuthStore` (task 7) actually needs.
///
/// `AuthRepository.register` only talks to `POST /auth/register` and hands
/// back an `AuthSession`; it never touches `SecureTokenStorage` itself. This
/// usecase is the one place that bridges the two: on success it persists the
/// returned `accessToken`/`refreshToken` pair and then returns just the
/// `User`, so `AuthStore` never has to see a raw token.
class SignUpUseCase {
  // A `required this._authRepository` named parameter is still callable as
  // `SignUpUseCase(authRepository: ...)` from outside this file; Dart
  // exposes the public name at the call site even though the field itself
  // stays private, the same pattern already used by `SyncService`.
  SignUpUseCase({
    required this._authRepository,
    required this._tokenStorage,
  });

  final AuthRepository _authRepository;
  final SecureTokenStorage _tokenStorage;

  /// Calls `POST /auth/register` with the given credentials and display
  /// name, persists the returned tokens on success, and returns the created
  /// `User`. A failed request is passed through unchanged as a `Left`.
  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = await _authRepository.register(
      email: email,
      password: password,
      displayName: displayName,
    );

    return result.match(
      (failure) async => Left(failure),
      (session) async {
        await _tokenStorage.saveTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
        return Right(session.user);
      },
    );
  }
}
