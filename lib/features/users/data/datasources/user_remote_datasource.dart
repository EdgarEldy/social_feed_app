import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../auth/data/models/user_model.dart';

/// Wraps every `dio` call against the user profile endpoints in the API
/// Contract: `GET /users/:id`, `PATCH /users/me` and `POST /users/me/avatar`.
///
/// Follows the precedent set by `AuthRemoteDatasource`: methods return
/// `Either<Failure, T>` directly rather than throwing, with any
/// [DioException] caught and funneled through [mapDioExceptionToFailure]
/// right here at the datasource boundary, plus a bare `catch` for a
/// malformed-but-2xx response body (a `TypeError`, not a subtype of
/// `Exception`, so `on Exception catch` would let it escape uncaught). `T`
/// is always a `data/` type (a [UserModel] or a raw `photoUrl` `String`),
/// never the domain `User`; mapping to the entity is the repository's job.
abstract class UserRemoteDatasource {
  /// Calls `GET /users/:id`.
  Future<Either<Failure, UserModel>> getUser(String id);

  /// Calls `PATCH /users/me` with `{ displayName? }`.
  Future<Either<Failure, UserModel>> updateCurrentUser({String? displayName});

  /// Calls `POST /users/me/avatar` as a multipart upload and returns the
  /// resulting `photoUrl` from `{ photoUrl }`.
  ///
  /// [onSendProgress] is forwarded straight to `dio.post`'s own parameter of
  /// the same name; it is invoked with `(sent, total)` byte counts as the
  /// multipart body streams to the server, letting a caller (ultimately
  /// `AvatarPicker`) drive a progress indicator. Its signature intentionally
  /// matches `dio`'s `ProgressCallback` structurally rather than importing
  /// it, so this abstract class's own signature stays free of a `dio` import
  /// even though the concrete implementation below is the one `data/` class
  /// allowed to depend on `dio` directly.
  Future<Either<Failure, String>> uploadAvatar(
    File image, {
    void Function(int sent, int total)? onSendProgress,
  });
}

class UserRemoteDatasourceImpl implements UserRemoteDatasource {
  UserRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, UserModel>> getUser(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.userById(id),
      );
      return Right(UserModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // Same reasoning as AuthRemoteDatasource: a malformed 2xx body throws
      // a TypeError, which `on Exception catch` would not catch.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> updateCurrentUser({
    String? displayName,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.currentUser,
        data: {'displayName': ?displayName},
      );
      return Right(UserModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(
    File image, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.currentUserAvatar,
        data: formData,
        onSendProgress: onSendProgress,
      );
      return Right(response.data!['photoUrl'] as String);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }
}
