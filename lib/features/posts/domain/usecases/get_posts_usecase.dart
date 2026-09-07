import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Loads a page of the feed, newest first.
///
/// A thin pass-through to `PostRepository.getPosts`; `PostsStore` calls this
/// for both the initial `loadPosts()` (no `cursor`) and the subsequent
/// `loadMore()` (the previous page's `nextCursor`), per the cursor-based
/// pagination described on `PaginatedResult`.
class GetPostsUseCase {
  GetPostsUseCase({required this._postRepository});

  final PostRepository _postRepository;

  /// Calls `GET /posts?cursor=&limit=`.
  Future<Either<Failure, PaginatedResult<Post>>> call({
    String? cursor,
    int? limit,
  }) {
    return _postRepository.getPosts(cursor: cursor, limit: limit);
  }
}
