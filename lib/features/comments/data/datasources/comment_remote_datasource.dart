import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../models/comment_model.dart';

/// Wraps every `dio` call against the comment endpoints in the API
/// Contract: `GET /posts/:postId/comments?cursor=&limit=`,
/// `POST /posts/:postId/comments` and `DELETE /comments/:id`.
///
/// Follows the exact same precedent [PostRemoteDatasource] set: methods
/// return `Either<Failure, T>` directly rather than throwing, with any
/// [DioException] caught and funneled through [mapDioExceptionToFailure]
/// right here at the datasource boundary, plus a bare `catch` for a
/// malformed-but-2xx response body (a `TypeError`, not a subtype of
/// `Exception`, so `on Exception catch` would let it escape uncaught). `T`
/// is always a `data/` type ([CommentModel], or a [PaginatedResult] of one),
/// never the domain `Comment`; mapping to the entity is the repository's
/// job.
///
/// [getComments] returns `PaginatedResult<CommentModel>` for the same
/// reasoning `PostRemoteDatasource.getPosts` documents for
/// `PaginatedResult<PostModel>`: `PaginatedResult` itself carries no domain
/// knowledge, it is a plain `{ items: List<T>, nextCursor: String? }` shape
/// generic over whatever `T` a caller plugs in, so instantiating it here
/// with the data-layer `CommentModel` is not a layering violation, exactly
/// like `List<CommentModel>` versus `List<Comment>` is not.
/// `CommentRepositoryImpl` is the only place that ever converts a
/// `PaginatedResult<CommentModel>` into a `PaginatedResult<Comment>`, by
/// mapping `items` through `CommentModel.toEntity()`.
abstract class CommentRemoteDatasource {
  /// Calls `GET /posts/:postId/comments?cursor=&limit=`.
  Future<Either<Failure, PaginatedResult<CommentModel>>> getComments(
    String postId, {
    String? cursor,
    int? limit,
  });

  /// Calls `POST /posts/:postId/comments` with `{ content }`.
  Future<Either<Failure, CommentModel>> addComment({
    required String postId,
    required String content,
  });

  /// Calls `DELETE /comments/:id`, expecting `204 No Content`.
  Future<Either<Failure, void>> deleteComment(String id);
}

class CommentRemoteDatasourceImpl implements CommentRemoteDatasource {
  CommentRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, PaginatedResult<CommentModel>>> getComments(
    String postId, {
    String? cursor,
    int? limit,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.postComments(postId),
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      final body = response.data!;
      final items = (body['items'] as List<dynamic>)
          .map((item) => CommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return Right(
        PaginatedResult(
          items: items,
          nextCursor: body['nextCursor'] as String?,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // A response that comes back 2xx but does not actually match the
      // documented shape throws a TypeError from the casts above, not a
      // DioException; the bare catch is what turns that into a Failure
      // instead of letting it escape uncaught, same reasoning as
      // PostRemoteDatasource.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, CommentModel>> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.postComments(postId),
        data: {'content': content},
      );
      return Right(CommentModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String id) async {
    try {
      await _dio.delete<void>(ApiEndpoints.commentById(id));
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    }
  }
}
