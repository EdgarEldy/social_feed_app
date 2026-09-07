import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Looks up a single post by id.
///
/// Not itself in the branch's literal task list, but added alongside the
/// four named usecases so `PostsStore.loadPost(String id)` (task 4) can
/// delegate to a usecase instead of reaching into `PostRepository`
/// directly, per the architecture rule that the presentation layer only
/// ever depends on `domain/`. Mirrors `GetUserUseCase` from `feature/users`
/// for the same reason.
class GetPostUseCase {
  GetPostUseCase({required this._postRepository});

  final PostRepository _postRepository;

  /// Calls `GET /posts/:id`.
  Future<Either<Failure, Post>> call(String id) {
    return _postRepository.getPost(id);
  }
}
