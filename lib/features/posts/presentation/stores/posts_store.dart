import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_usecase.dart';
import '../../domain/usecases/delete_post_usecase.dart';
import '../../domain/usecases/get_post_usecase.dart';
import '../../domain/usecases/get_posts_usecase.dart';
import '../../domain/usecases/update_post_usecase.dart';

part 'posts_store.g.dart';

/// Holds the state of the main feed (a paginated list of `Post`s) plus the
/// single post currently open on `PostDetailPage`.
///
/// ## Scoping: `get_it` singleton, not per-page
///
/// Unlike `UserStore` (see its class doc), the feed is not a stack of
/// independent, simultaneously-alive instances: there is only ever one feed
/// being scrolled, `FeedPage` is a single tab/root route, and there is no
/// scenario where two different `FeedPage`s with two different scroll
/// positions are alive on the navigation stack at once the way profile ->
/// profile -> profile can happen. That makes `PostsStore` closer in nature
/// to `AuthStore`/`ConnectivityStore` than to `UserStore`: a single
/// long-lived instance that the app constructs once and every interested
/// widget reads the same copy of. Registering it as a `get_it`
/// `registerLazySingleton` also means the feed's scroll position and loaded
/// pages survive a push to `PostDetailPage` and back, rather than refetching
/// page one every time the user returns to the feed.
///
/// ## Why `currentPost` lives on this same store
///
/// The branch's task list is explicit: "`PostsStore` ... exposes the
/// currently viewed post via an `@action loadPost(String id)`", so the
/// single-post detail state is deliberately kept here rather than split into
/// a separate `PostDetailStore`. To stop that from corrupting the feed list
/// when a detail page loads, the detail state uses its own observables
/// ([currentPost], [isLoadingCurrentPost], [currentPostError]) entirely
/// separate from the feed's own ([posts], [isLoadingFeed], [feedError]):
/// opening a `PostDetailPage` never touches [posts], and a concurrent
/// [loadMore] never touches [currentPost]. The two halves of this store are
/// otherwise independent, they just happen to share one `GetPostsUseCase`
/// caller's lifetime and one `get_it` registration.
class PostsStore = _PostsStore with _$PostsStore;

abstract class _PostsStore with Store {
  _PostsStore({
    required this._getPostsUseCase,
    required this._getPostUseCase,
    required this._createPostUseCase,
    required this._deletePostUseCase,
    required this._updatePostUseCase,
  });

  final GetPostsUseCase _getPostsUseCase;
  final GetPostUseCase _getPostUseCase;
  final CreatePostUseCase _createPostUseCase;
  final DeletePostUseCase _deletePostUseCase;
  final UpdatePostUseCase _updatePostUseCase;

  /// The feed, newest first. Cleared and refilled by [loadPosts], appended
  /// to by [loadMore].
  @observable
  ObservableList<Post> posts = ObservableList<Post>();

  /// Whether the initial/refresh [loadPosts] call is currently in flight.
  @observable
  bool isLoadingFeed = false;

  /// Whether a [loadMore] call is currently in flight.
  ///
  /// Kept separate from [isLoadingFeed] so `FeedPage` can show a full-page
  /// loader for the former and a small trailing spinner for the latter.
  @observable
  bool isLoadingMore = false;

  /// The failure from the most recent [loadPosts]/[loadMore] call, or
  /// `null`.
  @observable
  Failure? feedError;

  /// The cursor to pass to the next [loadMore] call, or `null` once the feed
  /// has reached its last page.
  ///
  /// Not itself observed by any widget; it only drives [loadMore]'s
  /// no-more-pages guard.
  String? _nextCursor;

  /// Whether at least one [loadPosts] call has completed, successfully or
  /// not. Lets `FeedPage` tell "nothing loaded yet" apart from "loaded and
  /// empty".
  @observable
  bool hasLoadedOnce = false;

  /// The post currently open on `PostDetailPage`, or `null` before the first
  /// successful [loadPost] call (or after one that failed).
  @observable
  Post? currentPost;

  /// Whether a [loadPost] call is currently in flight.
  @observable
  bool isLoadingCurrentPost = false;

  /// The failure from the most recent [loadPost] call, or `null`.
  @observable
  Failure? currentPostError;

  /// The id of the post currently being deleted via [deletePost], or `null`
  /// when no delete is in flight.
  ///
  /// Exposed so `PostCard` can disable its delete action (or show a small
  /// inline spinner) for the specific post being removed, without disabling
  /// every card in the feed at once.
  @observable
  String? deletingPostId;

  /// The failure from the most recent [deletePost] call, or `null`.
  @observable
  Failure? deleteError;

  /// The id of the post currently being edited via [updatePost], or `null`
  /// when no update is in flight.
  ///
  /// Same reasoning as [deletingPostId]: lets a specific `PostCard`/
  /// `CreatePostPage` disable itself for the post being edited without
  /// disabling the whole feed.
  @observable
  String? updatingPostId;

  /// The failure from the most recent [updatePost] call, or `null`.
  @observable
  Failure? updateError;

  /// Whether a [createPost] call is currently in flight.
  @observable
  bool creatingPost = false;

  /// The failure from the most recent [createPost] call, or `null`.
  @observable
  Failure? createError;

  /// Loads the first page of the feed via `GET /posts` (no `cursor`),
  /// replacing whatever is currently in [posts].
  ///
  /// Used both for the initial load and for pull-to-refresh; either way the
  /// feed starts over from the newest post.
  @action
  Future<void> loadPosts() async {
    isLoadingFeed = true;
    feedError = null;
    final result = await _getPostsUseCase();
    result.match(
      (failure) => feedError = failure,
      (page) {
        posts = ObservableList.of(page.items);
        _nextCursor = page.nextCursor;
      },
    );
    isLoadingFeed = false;
    hasLoadedOnce = true;
  }

  /// Loads the next page of the feed using the cursor from the last
  /// successful [loadPosts]/[loadMore] call, appending it to [posts].
  ///
  /// A no-op while a load is already in flight (guards against a fast
  /// scroll triggering the same page twice) and once [_nextCursor] is
  /// `null` (there is no further page to load).
  ///
  /// Deduped by id before appending: the usual remote response only ever
  /// contains posts not already in [posts], but `GetPostsUseCase` falls back
  /// to the local cache on a `NetworkFailure` (see
  /// `PostRepositoryImpl._getPostsFromCache`), and the cache has no real
  /// pagination concept, it always returns the *entire* cached set. Without
  /// this filter, that fallback would re-append every post already on
  /// screen. Filtering here is cheap and correct regardless of exactly why
  /// a duplicate might show up, so it stays even if the cache gains real
  /// pagination later.
  @action
  Future<void> loadMore() async {
    if (isLoadingMore || isLoadingFeed || _nextCursor == null) {
      return;
    }
    isLoadingMore = true;
    feedError = null;
    final result = await _getPostsUseCase(cursor: _nextCursor);
    result.match(
      (failure) => feedError = failure,
      (page) {
        final existingIds = posts.map((post) => post.id).toSet();
        final newPosts = page.items
            .where((post) => !existingIds.contains(post.id))
            .toList();
        posts.addAll(newPosts);
        _nextCursor = page.nextCursor;
      },
    );
    isLoadingMore = false;
  }

  /// Loads the post with the given [id] via `GET /posts/:id`, for
  /// `PostDetailPage`.
  ///
  /// Deliberately independent of [posts]/[isLoadingFeed]/[feedError]: opening
  /// a post's detail page never mutates the feed list, and a feed refresh
  /// happening at the same time never clobbers [currentPost].
  @action
  Future<void> loadPost(String id) async {
    isLoadingCurrentPost = true;
    currentPostError = null;
    final result = await _getPostUseCase(id);
    result.match(
      (failure) => currentPostError = failure,
      (post) => currentPost = post,
    );
    isLoadingCurrentPost = false;
  }

  /// Deletes the post identified by [id] via `DELETE /posts/:id`, removing
  /// it from [posts] on success.
  ///
  /// Only ever called by `PostCard` for a post the signed-in user authored;
  /// enforcing that rule is `PostCard`'s job (hiding the delete action for
  /// non-authors), per `DeletePostUseCase`'s own doc comment.
  @action
  Future<void> deletePost(String id) async {
    deletingPostId = id;
    deleteError = null;
    final result = await _deletePostUseCase(id);
    result.match(
      (failure) => deleteError = failure,
      (_) => posts.removeWhere((post) => post.id == id),
    );
    deletingPostId = null;
  }

  /// Edits the post identified by [id] via `PATCH /posts/:id`, reconciling
  /// both [posts] (so the feed reflects the edit) and [currentPost] (so a
  /// concurrently open `PostDetailPage` reflects it too), on success.
  ///
  /// Follows the same shape as [deletePost]: the store owns the usecase
  /// call directly rather than `CreatePostPage` resolving `UpdatePostUseCase`
  /// itself, so the same mutation-and-error bookkeeping lives in one place
  /// no matter who ends up triggering an edit later (`CreatePostPage` today,
  /// possibly a quick-edit affordance elsewhere down the line).
  @action
  Future<void> updatePost(String id, {String? title, String? content}) async {
    updatingPostId = id;
    updateError = null;
    final result = await _updatePostUseCase(id, title: title, content: content);
    result.match((failure) => updateError = failure, (post) {
      final index = posts.indexWhere((existing) => existing.id == id);
      if (index != -1) {
        posts[index] = post;
      }
      if (currentPost?.id == id) {
        currentPost = post;
      }
    });
    updatingPostId = null;
  }

  /// Creates a new post via `POST /posts`, prepending it to the front of
  /// [posts] on success so the feed reflects it as soon as
  /// [CreatePostPage] navigates away, without waiting for the next
  /// [loadPosts]/pull-to-refresh.
  ///
  /// [posts] is newest-first (see [posts]'s own doc and `GET /posts`'s
  /// contract), so a brand new post belongs at index 0, not appended at the
  /// end the way [loadMore]'s older page does.
  ///
  /// Follows the same shape as [updatePost]/[deletePost]: the store owns the
  /// usecase call rather than `CreatePostPage` resolving `CreatePostUseCase`
  /// itself, keeping mutation-and-error bookkeeping for the feed in one
  /// place. Returns the `Either` result so `CreatePostPage` can still decide
  /// where to navigate on success, the same as it did calling
  /// `CreatePostUseCase` directly.
  ///
  /// [onSendProgress] is required (rather than nullable, the way
  /// `CreatePostUseCase.call` declares it) purely to work around a
  /// `mobx_codegen` limitation: its generated `AsyncAction` wrapper drops
  /// the `?` off a nullable function-typed parameter, which does not
  /// type-check against this method's own signature. Every current caller
  /// (`CreatePostPage`) always supplies one anyway.
  @action
  Future<Either<Failure, Post>> createPost({
    required String title,
    required String content,
    File? image,
    required void Function(int sent, int total) onSendProgress,
  }) async {
    creatingPost = true;
    createError = null;
    final result = await _createPostUseCase(
      title: title,
      content: content,
      image: image,
      onSendProgress: onSendProgress,
    );
    result.match(
      (failure) => createError = failure,
      (post) => posts.insert(0, post),
    );
    creatingPost = false;
    return result;
  }
}
