import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../entities/auth_session.dart';
import '../entities/user.dart';

/// Persists an [AuthSession]'s token pair to [tokenStorage] and unwraps it
/// down to just the `User`, so callers never have to see a raw token.
///
/// `SignUpUseCase.call` and `SignInUseCase.call` used to each spell out this
/// exact same "save the tokens, then return `Right(session.user)`" dance on
/// their success branch. Both usecases hit a different endpoint
/// (`POST /auth/register` vs `POST /auth/login`) but end up with the
/// identical `AuthSession` shape, so this helper replaces the duplicated
/// logic with a single call site each usecase's `Right` branch delegates to.
Future<Either<Failure, User>> persistSessionAndReturnUser(
  AuthSession session,
  SecureTokenStorage tokenStorage,
) async {
  await tokenStorage.saveTokens(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  );
  return Right(session.user);
}
