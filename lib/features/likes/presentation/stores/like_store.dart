import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/usecases/toggle_like_usecase.dart';

part 'like_store.g.dart';

/// Holds the like state of a single post: whether the signed-in user likes
/// it and its current like count, with an optimistic [toggle].
///
/// ## Scoping: per widget instance, not a `get_it` singleton
///
/// The same [Post] can be on screen twice at once: once as a [PostCard] in
/// the feed and once again in [PostDetailPage], if the user navigated there
/// and the feed stayed mounted underneath. A shared singleton keyed by post
/// id is not what this branch's task list asks for either; it says "a
/// `LikeStore` per post", and the two on-screen widgets above are two
/// independent "instances of showing that post's like state", each of which
/// should be free to optimistically flip its own icon without the other
/// jumping in lockstep before the server has actually confirmed anything.
/// This mirrors `CommentsStore`/`UserStore`'s own per-instance scoping: each
/// `LikeButton` constructs its own `LikeStore` (seeded from that render's own
/// `Post.isLikedByMe`/`Post.likesCount`), pulling [ToggleLikeUseCase] from
/// `getIt`, and this store is intentionally not registered in
/// `injection_container.dart`.
///
/// ## Reconciliation and rollback
///
/// [toggle] flips [isLiked] and adjusts [likesCount] immediately, before the
/// network call resolves, so the tap feels instant. Once
/// [ToggleLikeUseCase] answers, a success reconciles both fields with the
/// server's own `{ liked, likesCount }` response rather than trusting the
/// optimistic guess, since another client could have liked/unliked the same
/// post in between. A failure instead rolls both fields back to their
/// pre-toggle values and records [error] for [LikeButton] to surface briefly.
class LikeStore = _LikeStore with _$LikeStore;

abstract class _LikeStore with Store {
  _LikeStore({
    required this.isLiked,
    required this.likesCount,
    required this._toggleLikeUseCase,
  });

  final ToggleLikeUseCase _toggleLikeUseCase;

  /// Whether the signed-in user currently likes the post, seeded from
  /// `Post.isLikedByMe` and kept in sync by [toggle].
  @observable
  bool isLiked;

  /// The post's current like count, seeded from `Post.likesCount` and kept
  /// in sync by [toggle].
  @observable
  int likesCount;

  /// Whether a [toggle] call is currently in flight, guarding against a
  /// second tap firing a second request before the first one resolves.
  @observable
  bool isToggling = false;

  /// The failure from the most recent [toggle] call, or `null`. Transient by
  /// design: [LikeButton] reads this once to show a discreet message, then
  /// calls [clearError] so the same failure does not linger and reappear on
  /// an unrelated rebuild.
  @observable
  Failure? error;

  /// Toggles the like on [postId], optimistically flipping [isLiked] and
  /// adjusting [likesCount] before `POST /posts/:postId/likes` resolves,
  /// then reconciling with (on success) or rolling back to (on failure) the
  /// pre-toggle state.
  ///
  /// A no-op while a previous call is still in flight, so a double tap
  /// cannot fire two overlapping toggles for the same post.
  @action
  Future<void> toggle(String postId) async {
    if (isToggling) {
      return;
    }
    isToggling = true;
    error = null;

    final previousIsLiked = isLiked;
    final previousLikesCount = likesCount;
    isLiked = !previousIsLiked;
    likesCount = isLiked ? previousLikesCount + 1 : previousLikesCount - 1;

    final result = await _toggleLikeUseCase(postId);
    result.match(
      (failure) {
        isLiked = previousIsLiked;
        likesCount = previousLikesCount;
        error = failure;
      },
      (response) {
        isLiked = response.liked;
        likesCount = response.likesCount;
      },
    );

    isToggling = false;
  }

  /// Clears [error] once [LikeButton] has shown it, so it does not resurface
  /// on a later, unrelated rebuild.
  @action
  void clearError() {
    error = null;
  }
}
