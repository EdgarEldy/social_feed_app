import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';

/// Contract for the like endpoints in the API Contract:
/// `POST /posts/:postId/likes` (toggle) and `GET /posts/:postId/likes/me`.
///
/// `domain/` must not import `data/models/like_model.dart`, so the two
/// data-layer response DTOs (`LikeToggleModel`/`LikeStatusModel`) never
/// appear here. Records carry the same two flat fields these endpoints
/// return without needing a dedicated named type: `toggleLike` mirrors
/// `{ liked, likesCount }`, and `getLikeStatus` mirrors `{ liked }`, which
/// collapses to a bare `bool` since it is the response's only field.
abstract class LikeRepository {
  /// Calls `POST /posts/:postId/likes`, which toggles the like and reports
  /// the resulting state.
  Future<Either<Failure, ({bool liked, int likesCount})>> toggleLike(
    String postId,
  );

  /// Calls `GET /posts/:postId/likes/me`, reporting whether the signed-in
  /// user currently likes the post.
  Future<Either<Failure, bool>> getLikeStatus(String postId);
}
