import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
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
  /// Comment[], nextCursor }`, returned as a record for the same reason.
  Future<Either<Failure, ({List<Comment> items, String? nextCursor})>>
  getComments(String postId, {String? cursor, int? limit});

  /// Calls `POST /posts/:postId/comments` with `{ content }`.
  Future<Either<Failure, Comment>> addComment(String postId, String content);

  /// Calls `DELETE /comments/:id`.
  Future<Either<Failure, void>> deleteComment(String id);
}
