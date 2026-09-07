import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Creates a new post, with an optional image.
///
/// Validates `title`/`content` before ever reaching `PostRepository`: an
/// empty title or content (after trimming surrounding whitespace) fails
/// immediately with a `ValidationFailure`, rather than sending a doomed
/// `POST /posts` request the backend would reject anyway. This is the one
/// usecase in this branch that is not a plain pass-through.
class CreatePostUseCase {
  CreatePostUseCase({required this._postRepository});

  final PostRepository _postRepository;

  /// Calls `POST /posts` as a multipart upload with `title`, `content` and
  /// an optional `image`, after confirming both `title` and `content` are
  /// non-empty once trimmed.
  ///
  /// [onSendProgress] is forwarded to `PostRepository.createPost`; see its
  /// doc for what it drives, the same precedent `UploadAvatarUseCase` set.
  Future<Either<Failure, Post>> call({
    required String title,
    required String content,
    File? image,
    void Function(int sent, int total)? onSendProgress,
  }) {
    if (title.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Title cannot be empty.')),
      );
    }
    if (content.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Content cannot be empty.')),
      );
    }
    return _postRepository.createPost(
      title: title,
      content: content,
      image: image,
      onSendProgress: onSendProgress,
    );
  }
}
