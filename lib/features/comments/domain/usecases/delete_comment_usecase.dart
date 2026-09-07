import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/comment_repository.dart';

/// Deletes a comment.
///
/// A thin pass-through to `CommentRepository.deleteComment`; the business
/// rule that a comment can be deleted by its own author or by the post's
/// author is a presentation-layer concern (hiding the delete action unless
/// one of those two conditions holds), the same precedent `DeletePostUseCase`
/// set for "only the author can delete a post": this usecase does not
/// enforce authorization on its own.
class DeleteCommentUseCase {
  DeleteCommentUseCase({required this._commentRepository});

  final CommentRepository _commentRepository;

  /// Calls `DELETE /comments/:id`.
  Future<Either<Failure, void>> call(String id) {
    return _commentRepository.deleteComment(id);
  }
}
