import 'package:freezed_annotation/freezed_annotation.dart';

part 'paginated_result.freezed.dart';

/// The shape shared by every cursor-paginated list endpoint in the API
/// Contract: `GET /posts?cursor=&limit=` and
/// `GET /posts/:postId/comments?cursor=&limit=` both respond with
/// `{ items, nextCursor }`.
///
/// `PostRepository.getPosts` and `CommentRepository.getComments` used to
/// each declare their own anonymous `({List<T> items, String? nextCursor})`
/// record for this. Both endpoints return the exact same shape, so a single
/// generic type here removes the duplication and gives the pagination
/// concept a name callers can refer to directly.
///
/// Built with `freezed` for the same reason as the domain entities: free
/// value equality and `copyWith`, with no Flutter/`dio`/`sqflite`
/// dependency, so this stays safe to use from `domain/`.
@freezed
abstract class PaginatedResult<T> with _$PaginatedResult<T> {
  const factory PaginatedResult({
    /// The page of items returned by this call.
    required List<T> items,

    /// The cursor to pass on the next call to fetch the following page, or
    /// `null` once there is no further page to load.
    String? nextCursor,
  }) = _PaginatedResult<T>;
}
