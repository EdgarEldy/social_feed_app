import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/user_model.dart';

/// The raw wire response shared by `POST /auth/register` and
/// `POST /auth/login`: `{ accessToken, refreshToken, user }`.
///
/// This is a plain Dart record rather than a `freezed` class because it
/// never leaves `data/`: [AuthRepositoryImpl] immediately unpacks it into
/// the domain-level `AuthSession` (which wraps a domain `User`, not this
/// [UserModel]). Introducing a named data-layer class just to shuttle three
/// fields one call up the stack would be ceremony without payoff.
typedef AuthSessionResponse = ({
  UserModel user,
  String accessToken,
  String refreshToken,
});

/// Wraps every `dio` call against the auth endpoints in the API Contract:
/// `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh` and
/// `POST /auth/logout`.
///
/// This is the first remote datasource in the codebase, so it sets the
/// precedent every later `*RemoteDatasource` (`feature/users`,
/// `feature/posts`, `feature/comments`) follows: methods return
/// `Either<Failure, T>` directly rather than throwing, with any
/// [DioException] caught and funneled through [mapDioExceptionToFailure]
/// right here at the datasource boundary. `T` is always a `data/` type
/// (a [UserModel], a raw token `String`, or the [AuthSessionResponse]
/// record above), never a domain entity; turning a model into a domain
/// entity is the repository's job, not the datasource's.
abstract class AuthRemoteDatasource {
  /// Calls `POST /auth/register` with `{ email, password, displayName }`.
  Future<Either<Failure, AuthSessionResponse>> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Calls `POST /auth/login` with `{ email, password }`.
  Future<Either<Failure, AuthSessionResponse>> login({
    required String email,
    required String password,
  });

  /// Calls `POST /auth/refresh` with `{ refreshToken }`, returning the new
  /// `accessToken` from the response.
  Future<Either<Failure, String>> refresh(String refreshToken);

  /// Calls `POST /auth/logout` with `{ refreshToken }`, expecting
  /// `204 No Content`.
  Future<Either<Failure, void>> logout(String refreshToken);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  AuthRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, AuthSessionResponse>> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _postForSession(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
  }

  @override
  Future<Either<Failure, AuthSessionResponse>> login({
    required String email,
    required String password,
  }) {
    return _postForSession(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
  }

  /// Shared body for [register] and [login]: both hit a different path but
  /// send/receive the identical shape, so the parsing and error-handling
  /// logic only needs to exist once.
  Future<Either<Failure, AuthSessionResponse>> _postForSession(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      final body = response.data!;
      final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
      return Right((
        user: user,
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      ));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // A response that comes back 2xx but does not actually match the
      // documented shape (missing key, wrong type) throws a TypeError from
      // the casts above, not a DioException. TypeError is a subtype of
      // Error, not Exception, so `on Exception catch` would silently miss
      // it and let it escape uncaught; the bare catch here is deliberate so
      // this kind of malformed-response bug becomes a Failure instead.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      return Right(response.data!['accessToken'] as String);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // Same reasoning as _postForSession: a malformed 2xx body throws a
      // TypeError, which `on Exception catch` would not catch.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    }
  }
}
