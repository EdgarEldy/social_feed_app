import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/like_model.dart';

/// Wraps every `dio` call against the like endpoints in the API Contract:
/// `POST /posts/:postId/likes` (toggles the like) and
/// `GET /posts/:postId/likes/me` (reports the signed-in user's current
/// status).
///
/// Follows the exact same precedent every other remote datasource in this
/// codebase sets: methods return `Either<Failure, T>` directly rather than
/// throwing, with any [DioException] caught and funneled through
/// [mapDioExceptionToFailure] right here at the datasource boundary, plus a
/// bare `catch` for a malformed-but-2xx response body (a `TypeError`, not a
/// subtype of `Exception`, so `on Exception catch` would let it escape
/// uncaught). `T` is always a `data/` type ([LikeToggleModel]/
/// [LikeStatusModel]), never a domain type, mapping to the plain record/bool
/// shapes `LikeRepository` declares is the repository's job.
///
/// Unlike `PostRemoteDatasource`/`CommentRemoteDatasource`, there is no
/// paired `LikeLocalDatasource` on this branch's task list: likes are not
/// cached offline or queued through `pending_writes`, this feature is
/// live-only.
abstract class LikeRemoteDatasource {
  /// Calls `POST /posts/:postId/likes`, which toggles the like and reports
  /// the resulting state.
  Future<Either<Failure, LikeToggleModel>> toggleLike(String postId);

  /// Calls `GET /posts/:postId/likes/me`, reporting whether the signed-in
  /// user currently likes the post.
  Future<Either<Failure, LikeStatusModel>> getLikeStatus(String postId);
}

class LikeRemoteDatasourceImpl implements LikeRemoteDatasource {
  LikeRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, LikeToggleModel>> toggleLike(String postId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.postLikes(postId),
      );
      return Right(LikeToggleModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // A response that comes back 2xx but does not actually match the
      // documented shape throws a TypeError from fromJson above, not a
      // DioException; the bare catch is what turns that into a Failure
      // instead of letting it escape uncaught, same reasoning as every
      // other remote datasource in this codebase.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, LikeStatusModel>> getLikeStatus(
    String postId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.postLikesMe(postId),
      );
      return Right(LikeStatusModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }
}
