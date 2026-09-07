import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/post_repository.dart';

/// Deletes a post the current user authored.
///
/// A thin pass-through to `PostRepository.deletePost`; the business rule
/// that only the author may delete a post is a presentation-layer concern
/// (hiding the delete action for non-authors), not something this usecase
/// enforces on its own.
class DeletePostUseCase {
  DeletePostUseCase({required this._postRepository});

  final PostRepository _postRepository;

  /// Calls `DELETE /posts/:id`.
  Future<Either<Failure, void>> call(String id) {
    return _postRepository.deletePost(id);
  }
}
