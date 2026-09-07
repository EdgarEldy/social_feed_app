import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

/// Adds a new comment to a post.
///
/// Validates `content` before ever reaching `CommentRepository`: empty
/// content (after trimming surrounding whitespace) fails immediately with a
/// `ValidationFailure`, rather than sending a doomed
/// `POST /posts/:postId/comments` request the backend would reject anyway.
/// This is the exact same precedent `CreatePostUseCase` set for `title`/
/// `content`, and is what satisfies this branch's "reject empty content"
/// business rule.
class AddCommentUseCase {
  AddCommentUseCase({required this._commentRepository});

  final CommentRepository _commentRepository;

  /// Calls `POST /posts/:postId/comments` with `{ content }`, after
  /// confirming `content` is non-empty once trimmed.
  Future<Either<Failure, Comment>> call({
    required String postId,
    required String content,
  }) {
    if (content.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Comment content cannot be empty.')),
      );
    }
    return _commentRepository.addComment(postId: postId, content: content);
  }
}
