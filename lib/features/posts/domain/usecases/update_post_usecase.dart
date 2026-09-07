import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Edits an existing post's title and/or content.
///
/// A thin pass-through to `PostRepository.updatePost`; leaving `title`/
/// `content` `null` means "no change" and is forwarded to the repository
/// unchanged, the same convention `UpdateUserUseCase` uses for
/// `displayName`.
class UpdatePostUseCase {
  UpdatePostUseCase({required this._postRepository});

  final PostRepository _postRepository;

  /// Calls `PATCH /posts/:id` with `{ title?, content? }`.
  Future<Either<Failure, Post>> call(
    String id, {
    String? title,
    String? content,
  }) {
    return _postRepository.updatePost(id, title: title, content: content);
  }
}
