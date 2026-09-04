import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Concrete [AuthRepository], delegating to [AuthRemoteDatasource].
///
/// There is no local datasource here, unlike `PostRepositoryImpl`/
/// `CommentRepositoryImpl`: authentication has no offline-first read to
/// coordinate, the auth endpoints have no meaningful cached fallback. The
/// only job left for this class is translating [AuthRemoteDatasource]'s
/// data-layer return shapes (an [AuthSessionResponse], a raw `String`) into
/// the domain-level `Either<Failure, T>` shapes [AuthRepository] declares,
/// and mapping the wire-level `UserModel` onto the domain `User` via
/// `toEntity()` along the way. It stays stateless on purpose, per [AuthRepository]'s
/// documentation: it never reads from or writes to `SecureTokenStorage`.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDatasource);

  final AuthRemoteDatasource _remoteDatasource;

  @override
  Future<Either<Failure, AuthSession>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = await _remoteDatasource.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    return result.map(_toAuthSession);
  }

  @override
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    final result = await _remoteDatasource.login(
      email: email,
      password: password,
    );
    return result.map(_toAuthSession);
  }

  @override
  Future<Either<Failure, String>> refresh(String refreshToken) {
    return _remoteDatasource.refresh(refreshToken);
  }

  @override
  Future<Either<Failure, void>> logout(String refreshToken) {
    return _remoteDatasource.logout(refreshToken);
  }

  AuthSession _toAuthSession(AuthSessionResponse response) {
    return AuthSession(
      user: response.user.toEntity(),
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }
}
