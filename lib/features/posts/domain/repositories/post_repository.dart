import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../entities/post.dart';

/// Contract for the post endpoints in the API Contract: `GET /posts`,
/// `GET /posts/:id`, `POST /posts`, `PATCH /posts/:id` and
/// `DELETE /posts/:id`.
///
/// The implementation in `data/repositories/post_repository_impl.dart`
/// coordinates a remote (`dio`) and a local (`sqflite`) datasource per the
/// offline-first strategy documented in `feature/offline-and-sync`: try
/// remote first, fall back to the cache on `NetworkFailure`, write-through
/// successful remote reads to the cache.
abstract class PostRepository {
  /// Calls `GET /posts?cursor=&limit=`.
  ///
  /// The response is `{ items: Post[], nextCursor }`, modeled by the shared
  /// `PaginatedResult` type also used by `CommentRepository.getComments`;
  /// `nextCursor` is `null` once there is no further page to load.
  Future<Either<Failure, PaginatedResult<Post>>> getPosts({
    String? cursor,
    int? limit,
  });

  /// Calls `GET /posts/:id`.
  Future<Either<Failure, Post>> getPost(String id);

  /// Calls `POST /posts` as a multipart upload with `title`, `content` and
  /// an optional `image`.
  ///
  /// `File` is used directly for `image`, matching README's
  /// `createPost(Post post, {File? image})` reference example.
  ///
  /// [onSendProgress] is forwarded down to `PostRemoteDatasource.createPost`
  /// and, from there, straight to `dio`'s own `onSendProgress` parameter,
  /// following the exact precedent `UserRepository.uploadAvatar` set for the
  /// avatar upload: a caller such as `CreatePostPage` can drive a progress
  /// indicator while the multipart body streams. Its signature is written
  /// out by hand rather than importing `dio`'s `ProgressCallback` typedef,
  /// since `domain/` never imports `dio`. It only ever fires on the remote
  /// path; a create made while offline (see `PostRepositoryImpl`'s class
  /// doc) has no request in flight to report progress on.
  Future<Either<Failure, Post>> createPost({
    required String title,
    required String content,
    File? image,
    void Function(int sent, int total)? onSendProgress,
  });

  /// Calls `PATCH /posts/:id` with `{ title?, content? }`.
  Future<Either<Failure, Post>> updatePost(
    String id, {
    String? title,
    String? content,
  });

  /// Calls `DELETE /posts/:id`.
  Future<Either<Failure, void>> deletePost(String id);
}
