import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../models/post_model.dart';

/// Wraps every `dio` call against the post endpoints in the API Contract:
/// `GET /posts?cursor=&limit=`, `GET /posts/:id`, `POST /posts`,
/// `PATCH /posts/:id` and `DELETE /posts/:id`.
///
/// Follows the same precedent `AuthRemoteDatasource`/`UserRemoteDatasource`
/// set: methods return `Either<Failure, T>` directly rather than throwing,
/// with any [DioException] caught and funneled through
/// [mapDioExceptionToFailure] right here at the datasource boundary, plus a
/// bare `catch` for a malformed-but-2xx response body (a `TypeError`, not a
/// subtype of `Exception`, so `on Exception catch` would let it escape
/// uncaught). `T` is always a `data/` type (a [PostModel], or a
/// [PaginatedResult] of one), never the domain `Post`; mapping to the
/// entity is the repository's job.
///
/// ## Why [getPosts] returns `PaginatedResult<PostModel>`, not a new type
///
/// `PostRepository.getPosts` returns `Either<Failure, PaginatedResult<Post>>`
/// with the domain entity `Post` as the type argument. `PaginatedResult`
/// itself (`core/pagination/paginated_result.dart`) carries no domain
/// knowledge: it is a plain `{ items: List<T>, nextCursor: String? }` shape,
/// generic over whatever `T` a caller plugs in, with no `Post` import of its
/// own. That is exactly the same relationship `List<T>` has to `domain/`
/// versus `data/`, using `List<PostModel>` in `data/` and `List<Post>` in
/// `domain/` is not considered a layering violation anywhere else in this
/// codebase, so instantiating `PaginatedResult<PostModel>` here rather than
/// inventing a second, structurally identical data-layer record is not one
/// either. `PostRepositoryImpl` is the only place that ever converts a
/// `PaginatedResult<PostModel>` into a `PaginatedResult<Post>`, by mapping
/// `items` through `PostModel.toEntity()`.
abstract class PostRemoteDatasource {
  /// Calls `GET /posts?cursor=&limit=`.
  Future<Either<Failure, PaginatedResult<PostModel>>> getPosts({
    String? cursor,
    int? limit,
  });

  /// Calls `GET /posts/:id`.
  Future<Either<Failure, PostModel>> getPost(String id);

  /// Calls `POST /posts` as a multipart upload with `title`, `content` and
  /// an optional `image`.
  ///
  /// [onSendProgress] is forwarded straight to `dio.post`'s own parameter of
  /// the same name, exactly as `UserRemoteDatasource.uploadAvatar` does for
  /// the avatar upload: it is invoked with `(sent, total)` byte counts as
  /// the multipart body streams, letting a caller (`CreatePostPage`) drive a
  /// progress indicator while the image itself uploads.
  Future<Either<Failure, PostModel>> createPost({
    required String title,
    required String content,
    File? image,
    void Function(int sent, int total)? onSendProgress,
  });

  /// Calls `PATCH /posts/:id` with `{ title?, content? }`.
  Future<Either<Failure, PostModel>> updatePost(
    String id, {
    String? title,
    String? content,
  });

  /// Calls `DELETE /posts/:id`, expecting `204 No Content`.
  Future<Either<Failure, void>> deletePost(String id);
}

class PostRemoteDatasourceImpl implements PostRemoteDatasource {
  PostRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, PaginatedResult<PostModel>>> getPosts({
    String? cursor,
    int? limit,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.posts,
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      final body = response.data!;
      final items = (body['items'] as List<dynamic>)
          .map((item) => PostModel.fromJson(item as Map<String, dynamic>))
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
      // AuthRemoteDatasource/UserRemoteDatasource.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, PostModel>> getPost(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.postById(id),
      );
      return Right(PostModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, PostModel>> createPost({
    required String title,
    required String content,
    File? image,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'content': content,
        if (image != null) 'image': await MultipartFile.fromFile(image.path),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.posts,
        data: formData,
        onSendProgress: onSendProgress,
      );
      return Right(PostModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // Also covers a missing/unreadable image file (a FileSystemException
      // from MultipartFile.fromFile above), which is not a DioException
      // either; surfacing it as a ServerFailure keeps it inside the
      // Either<Failure, T> contract rather than throwing out of data/.
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, PostModel>> updatePost(
    String id, {
    String? title,
    String? content,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.postById(id),
        data: {'title': ?title, 'content': ?content},
      );
      return Right(PostModel.fromJson(response.data!));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('Unexpected response from server: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String id) async {
    try {
      await _dio.delete<void>(ApiEndpoints.postById(id));
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    }
  }
}
