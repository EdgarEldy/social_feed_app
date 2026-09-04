import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../entities/comment.dart';

/// Contract for the comment endpoints in the API Contract:
/// `GET /posts/:postId/comments`, `POST /posts/:postId/comments` and
/// `DELETE /comments/:id`.
///
/// Coordinates a remote (`dio`) and a local (`sqflite`) datasource in its
/// implementation, per the same offline-first strategy as `PostRepository`.
abstract class CommentRepository {
  /// Calls `GET /posts/:postId/comments?cursor=&limit=`.
  ///
  /// Mirrors `PostRepository.getPosts`'s paginated shape: `{ items:
  /// Comment[], nextCursor }`, modeled by the same shared `PaginatedResult`
  /// type.
  Future<Either<Failure, PaginatedResult<Comment>>> getComments(
    String postId, {
    String? cursor,
    int? limit,
  });

  /// Calls `POST /posts/:postId/comments` with `{ content }`.
  ///
  /// [postId] and [content] are both named to avoid an accidental swap
  /// between two adjacent `String` parameters, the same reasoning behind
  /// `AuthRepository.register`/`login` using named parameters.
  Future<Either<Failure, Comment>> addComment({
    required String postId,
    required String content,
  });

  /// Calls `DELETE /comments/:id`.
  Future<Either<Failure, void>> deleteComment(String id);
}
