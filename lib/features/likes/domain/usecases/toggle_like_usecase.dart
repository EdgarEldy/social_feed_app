import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/like_repository.dart';

/// Toggles the signed-in user's like on a post.
///
/// A thin pass-through to [LikeRepository.toggleLike], same as
/// `GetPostUseCase`/`GetCommentsUseCase`: there is no validation to perform
/// before calling the repository, `LikeStore` (built later in this branch)
/// is what layers the optimistic UI update on top of this call.
class ToggleLikeUseCase {
  ToggleLikeUseCase({required this._likeRepository});

  final LikeRepository _likeRepository;

  /// Calls `POST /posts/:postId/likes`.
  Future<Either<Failure, ({bool liked, int likesCount})>> call(
    String postId,
  ) {
    return _likeRepository.toggleLike(postId);
  }
}
