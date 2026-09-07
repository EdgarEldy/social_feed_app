import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/comment.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/get_comments_usecase.dart';

part 'comments_store.g.dart';

/// Holds the state of one post's comment thread: the paginated list itself,
/// plus the in-flight state for adding and deleting a comment.
///
/// ## Scoping: per-page, not a `get_it` singleton
///
/// Same reasoning as `UserStore`'s class doc: `PostDetailPage` is reached via
/// `/posts/:id`, and nothing stops the user from navigating post -> post
/// (e.g. tapping an author's name, or a "related post" link) while an
/// earlier `PostDetailPage` stays alive underneath on the navigation stack.
/// A shared singleton would leak one post's comment thread into another's
/// screen for at least a frame, or forever if `go_router` keeps the earlier
/// page alive without re-triggering a load. The branch task list is explicit
/// about this too: `CommentsStore` is "instantiated per `PostDetailPage` and
/// disposed with it", not resolved from `get_it`.
///
/// `PostDetailPage` therefore constructs its own `CommentsStore` directly
/// (pulling the three usecases below from `getIt`), typically in `initState`,
/// and this store is intentionally not registered in
/// `injection_container.dart`.
///
/// ## Why `addComment`/`deleteComment` refetch instead of mutating locally
///
/// `PostsStore.createPost`/`deletePost` update `posts` in place (insert at
/// the front, remove by id) as an optimization: the feed can be long, and
/// there is no reason to refetch the whole first page just to reflect one
/// new or removed post. `CommentsStore` deliberately does not follow that
/// precedent. The branch task list spells out "refreshed after each
/// mutation" for both `addComment` and `deleteComment`, and a plain refetch
/// is also the simpler, more obviously correct choice here: a thread is
/// small, and a fresh `loadComments` call sidesteps any local bookkeeping
/// mistake around where exactly to insert a new comment relative to
/// `comments`' oldest-to-newest order, or around another comment having been
/// added by someone else between this page's load and this mutation. This is
/// an intentional divergence from `PostsStore`, not an oversight.
///
/// ## No live subscription to dispose
///
/// The README's own "Concepts Covered" section names this store as the
/// canonical example of "disposing reactions and per-page stores ... when
/// leaving a screen", but that refers to `PostDetailPage` dropping its
/// reference to this store (and letting it get garbage collected) when the
/// page is popped, not to this class holding a `dispose()` method itself.
/// Every field here is a plain `@observable` set directly by an `@action`;
/// none of them is a MobX `reaction`/`autorun`/`when` subscription or any
/// other resource that needs to be closed. `PostDetailPage` disposing its
/// `CommentsStore` therefore just means "stop holding a reference to it",
/// there is nothing further for this class to clean up.
class CommentsStore = _CommentsStore with _$CommentsStore;

abstract class _CommentsStore with Store {
  _CommentsStore({
    required this._getCommentsUseCase,
    required this._addCommentUseCase,
    required this._deleteCommentUseCase,
  });

  final GetCommentsUseCase _getCommentsUseCase;
  final AddCommentUseCase _addCommentUseCase;
  final DeleteCommentUseCase _deleteCommentUseCase;

  /// The comment thread for the post currently open in `PostDetailPage`,
  /// oldest first per the API's cursor-based pagination. Cleared and
  /// refilled by [loadComments], appended to by [loadMore].
  @observable
  ObservableList<Comment> comments = ObservableList<Comment>();

  /// Whether the initial/refresh [loadComments] call is currently in flight.
  @observable
  bool isLoading = false;

  /// Whether a [loadMore] call is currently in flight.
  ///
  /// Kept separate from [isLoading] for the same reason as
  /// `PostsStore.isLoadingMore`: `CommentsSection` can show a full-section
  /// loader for the former and a small trailing spinner for the latter.
  @observable
  bool isLoadingMore = false;

  /// The failure from the most recent [loadComments]/[loadMore] call, or
  /// `null`.
  @observable
  Failure? error;

  /// The cursor to pass to the next [loadMore] call, or `null` once the
  /// thread has reached its last page.
  ///
  /// Not itself observed by any widget; it only drives [loadMore]'s
  /// no-more-pages guard, the same as `PostsStore._nextCursor`.
  String? _nextCursor;

  /// Whether at least one [loadComments] call has completed, successfully or
  /// not. Lets `CommentsSection` tell "nothing loaded yet" apart from
  /// "loaded and empty".
  @observable
  bool hasLoadedOnce = false;

  /// Whether an [addComment] call is currently in flight.
  @observable
  bool isSubmitting = false;

  /// The failure from the most recent [addComment] call, or `null`.
  @observable
  Failure? submitError;

  /// The id of the comment currently being deleted via [deleteComment], or
  /// `null` when no delete is in flight.
  ///
  /// Exposed so `CommentTile` can disable its own delete action (or show a
  /// small inline spinner) for the specific comment being removed, without
  /// disabling every tile in the thread at once, mirroring
  /// `PostsStore.deletingPostId`.
  @observable
  String? deletingCommentId;

  /// The failure from the most recent [deleteComment] call, or `null`.
  @observable
  Failure? deleteError;

  /// Loads the first page of comments for [postId] via
  /// `GET /posts/:postId/comments` (no `cursor`), replacing whatever is
  /// currently in [comments].
  ///
  /// Used for the initial load, pull-to-refresh, and as the refetch step
  /// after a successful [addComment]/[deleteComment] (see this class's own
  /// doc for why those mutations refetch instead of mutating [comments]
  /// locally).
  @action
  Future<void> loadComments(String postId) async {
    isLoading = true;
    error = null;
    final result = await _getCommentsUseCase(postId: postId);
    result.match(
      (failure) => error = failure,
      (page) {
        comments = ObservableList.of(page.items);
        _nextCursor = page.nextCursor;
      },
    );
    isLoading = false;
    hasLoadedOnce = true;
  }

  /// Loads the next page of comments for [postId] using the cursor from the
  /// last successful [loadComments]/[loadMore] call, appending it to
  /// [comments].
  ///
  /// A no-op while a load is already in flight, or once [_nextCursor] is
  /// `null`, mirroring `PostsStore.loadMore`'s guard.
  @action
  Future<void> loadMore(String postId) async {
    if (isLoadingMore || isLoading || _nextCursor == null) {
      return;
    }
    isLoadingMore = true;
    error = null;
    final result = await _getCommentsUseCase(postId: postId, cursor: _nextCursor);
    result.match(
      (failure) => error = failure,
      (page) {
        final existingIds = comments.map((comment) => comment.id).toSet();
        final newComments =
            page.items.where((comment) => !existingIds.contains(comment.id)).toList();
        comments.addAll(newComments);
        _nextCursor = page.nextCursor;
      },
    );
    isLoadingMore = false;
  }

  /// Adds a new comment to [postId] via `POST /posts/:postId/comments`, then
  /// reloads the first page of [comments] on success.
  ///
  /// Refetches rather than inserting the new `Comment` locally; see this
  /// class's own doc for why that diverges from `PostsStore.createPost`.
  @action
  Future<void> addComment(String postId, String content) async {
    isSubmitting = true;
    submitError = null;
    final result = await _addCommentUseCase(postId: postId, content: content);
    await result.match(
      (failure) async => submitError = failure,
      (_) async => loadComments(postId),
    );
    isSubmitting = false;
  }

  /// Deletes the comment identified by [id] via `DELETE /comments/:id`, then
  /// reloads the first page of [comments] for [postId] on success.
  ///
  /// Refetches rather than removing the comment locally; see this class's
  /// own doc for why that diverges from `PostsStore.deletePost`.
  ///
  /// Only ever called by `CommentTile` for a comment the signed-in user
  /// authored, or by the post's own author; enforcing that rule is
  /// `CommentTile`'s job, per `DeleteCommentUseCase`'s own doc comment.
  @action
  Future<void> deleteComment(String id, String postId) async {
    deletingCommentId = id;
    deleteError = null;
    final result = await _deleteCommentUseCase(id);
    await result.match(
      (failure) async => deleteError = failure,
      (_) async => loadComments(postId),
    );
    deletingCommentId = null;
  }
}
