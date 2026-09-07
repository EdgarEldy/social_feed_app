import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

/// Loads a page of comments for a post, oldest to newest per the API's
/// cursor-based pagination.
///
/// A thin pass-through to `CommentRepository.getComments`; `CommentsStore`
/// calls this both for the initial load of `PostDetailPage`'s
/// `CommentsSection` and any subsequent "load more" as the user scrolls,
/// mirroring `GetPostsUseCase`'s own precedent for `PostsStore`.
class GetCommentsUseCase {
  GetCommentsUseCase({required this._commentRepository});

  final CommentRepository _commentRepository;

  /// Calls `GET /posts/:postId/comments?cursor=&limit=`.
  Future<Either<Failure, PaginatedResult<Comment>>> call({
    required String postId,
    String? cursor,
    int? limit,
  }) {
    return _commentRepository.getComments(postId, cursor: cursor, limit: limit);
  }
}
