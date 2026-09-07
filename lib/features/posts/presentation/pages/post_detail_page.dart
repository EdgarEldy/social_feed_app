import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/stores/auth_store.dart';
import '../../../comments/domain/usecases/add_comment_usecase.dart';
import '../../../comments/domain/usecases/delete_comment_usecase.dart';
import '../../../comments/domain/usecases/get_comments_usecase.dart';
import '../../../comments/presentation/stores/comments_store.dart';
import '../../../comments/presentation/widgets/comment_input.dart';
import '../../../comments/presentation/widgets/comments_section.dart';
import '../../../likes/domain/usecases/toggle_like_usecase.dart';
import '../../../likes/presentation/stores/like_store.dart';
import '../../../likes/presentation/widgets/like_button.dart';
import '../../domain/entities/post.dart';
import '../stores/posts_store.dart';

/// The height reserved for a post's attached image on the detail page.
///
/// Taller than [PostCard]'s own `_postImageHeight`, since this page has the
/// whole screen to itself rather than sharing space with a scrolling list of
/// other cards, but the same [BoxFit.cover] keeps the crop behavior (and
/// therefore the [Hero] animation) consistent between the two.
const double _postDetailImageHeight = 260;

/// How close to the bottom of the page's scroll extent (in logical pixels)
/// the user has to get before the next page of comments starts loading.
///
/// Mirrors `FeedPage`'s own `_loadMoreThreshold`: comments paginate off the
/// same `SingleChildScrollView` this page already scrolls, rather than a
/// second independent scroll surface (see `CommentsSection`'s own doc for
/// why it renders as a non-scrolling `ListView`).
const double _commentsLoadMoreThreshold = 300;

/// The full-post screen reached from a [PostCard] tap or a deep link,
/// showing a post's title, content, author, image, and read-only
/// comment/like counts.
///
/// ## Where the [Post] comes from
///
/// [PostCard] already holds the full [Post] it renders, so tapping it pushes
/// this route with that [Post] attached as `extra`, avoiding a redundant
/// `GET /posts/:id` round trip; that is the [initialPost] case. [initialPost]
/// only seeds the very first frame though: [build] re-reads the same post by
/// id from [PostsStore.posts] inside an [Observer] on every rebuild, falling
/// back to [initialPost] if it is not (or no longer) present there, so an
/// edit made from this page's own author menu (which writes through to
/// [PostsStore.posts], see [PostsStore.updatePost]) shows up immediately
/// instead of only after leaving and returning to the page. A route reached
/// without that `extra` (a deep link, a cold start restoring this route
/// directly) has no such in-memory [Post], so this page instead calls
/// [PostsStore.loadPost] and renders its loading/error/data observables
/// through an [Observer], the same fallback shape `_EditPostRoute` in
/// `app_router.dart` used to use for the edit route before that route moved
/// to its own local, per-instance state to avoid colliding with this page's
/// use of the same [PostsStore.currentPost] slot.
///
/// ## What is out of scope on this branch
///
/// Per the Screens table, this page is meant to eventually show "Full post,
/// comments, and like button". `feature/comments` and `feature/likes` are
/// later branches (see the README's "Order of Work") that have not landed
/// yet, so the comment/like counts rendered here are the same read-only
/// numbers [PostCard] shows, not a real comments list or a tappable like
/// button; see [_PostDetailStats] for where each plugs in later, the same
/// deferred-extension pattern `ProfilePage` uses for its own post grid.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId, this.initialPost});

  /// The id of the post to show, from the `/posts/:id` route parameter.
  final String postId;

  /// The post itself, when navigated here from a widget that already had it
  /// in memory (see the class doc). `null` triggers the [PostsStore.loadPost]
  /// fallback.
  final Post? initialPost;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostsStore _postsStore = getIt<PostsStore>();

  // CommentsStore is deliberately not resolved via getIt<CommentsStore>():
  // it is not registered in injection_container.dart at all, per its own
  // class doc, since it is scoped to one PostDetailPage instance rather than
  // shared app-wide. This page constructs it directly from the three
  // usecases getIt does own, and simply drops the reference when this State
  // is disposed.
  final CommentsStore _commentsStore = CommentsStore(
    getCommentsUseCase: getIt<GetCommentsUseCase>(),
    addCommentUseCase: getIt<AddCommentUseCase>(),
    deleteCommentUseCase: getIt<DeleteCommentUseCase>(),
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPost == null) {
      _postsStore.loadPost(widget.postId);
    }
    _commentsStore.loadComments(widget.postId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - _commentsLoadMoreThreshold) {
      _commentsStore.loadMore(widget.postId);
    }
  }

  Future<void> _handleDelete(Post post) async {
    await _postsStore.deletePost(post.id);
    if (!mounted) return;
    final error = _postsStore.deleteError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    context.pop();
  }

  Future<void> _openAddCommentSheet(Post post) {
    return showModalBottomSheet<void>(
      context: context,
      // Lets the sheet grow to fit its content instead of being capped at
      // roughly half the screen height, which matters once the on-screen
      // keyboard also claims a chunk of the viewport.
      isScrollControlled: true,
      builder: (sheetContext) {
        return _AddCommentSheet(commentsStore: _commentsStore, post: post);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPost = widget.initialPost;
    if (initialPost != null) {
      return Observer(
        builder: (_) {
          // Re-read the post from the feed list on every rebuild instead of
          // permanently rendering the constructor's initialPost, so an edit
          // made from this same page's own author menu (which updates
          // PostsStore.posts, see updatePost's doc) is reflected without
          // leaving and re-entering the page. Falls back to initialPost when
          // it is not (or no longer) in posts, e.g. a post loaded from a
          // cache-fallback page that never made it into the feed list, or a
          // page further along in pagination than what is currently loaded.
          final post = _postsStore.posts.firstWhere(
            (candidate) => candidate.id == initialPost.id,
            orElse: () => initialPost,
          );
          return _PostDetailScaffold(
            post: post,
            onDelete: () => _handleDelete(post),
            commentsStore: _commentsStore,
            scrollController: _scrollController,
            onAddComment: () => _openAddCommentSheet(post),
          );
        },
      );
    }
    return Observer(
      builder: (_) {
        if (_postsStore.isLoadingCurrentPost) {
          return Scaffold(
            appBar: AppBar(),
            body: const LoadingIndicator(semanticsLabel: 'Loading post'),
          );
        }
        final error = _postsStore.currentPostError;
        if (error != null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              message: error.message,
              onRetry: () => _postsStore.loadPost(widget.postId),
            ),
          );
        }
        final post = _postsStore.currentPost;
        if (post == null || post.id != widget.postId) {
          return const Scaffold(
            body: ErrorView(message: 'Post not found.'),
          );
        }
        return _PostDetailScaffold(
          post: post,
          onDelete: () => _handleDelete(post),
          commentsStore: _commentsStore,
          scrollController: _scrollController,
          onAddComment: () => _openAddCommentSheet(post),
        );
      },
    );
  }
}

/// The app bar and scrollable body for a loaded [post].
///
/// Split out from [_PostDetailPageState] so the loading/error/data branching
/// above stays readable, keeping both well under the ~150 line guideline.
class _PostDetailScaffold extends StatelessWidget {
  const _PostDetailScaffold({
    required this.post,
    required this.onDelete,
    required this.commentsStore,
    required this.scrollController,
    required this.onAddComment,
  });

  final Post post;
  final VoidCallback onDelete;
  final CommentsStore commentsStore;
  final ScrollController scrollController;
  final VoidCallback onAddComment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [_PostDetailAuthorMenu(post: post, onDelete: onDelete)],
      ),
      body: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: _PostDetailContent(post: post, commentsStore: commentsStore),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddComment,
        tooltip: 'Add comment',
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}

/// The edit/delete affordance shown only to [post]'s own author, mirroring
/// [PostCard]'s own author-only menu (`_PostAuthorMenu`) so the same action
/// is available from both the feed and the detail page.
class _PostDetailAuthorMenu extends StatelessWidget {
  const _PostDetailAuthorMenu({required this.post, required this.onDelete});

  final Post post;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final isAuthor = getIt<AuthStore>().currentUser?.id == post.authorId;
        if (!isAuthor) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Post actions',
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/posts/${post.id}/edit', extra: post);
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        );
      },
    );
  }
}

/// [post]'s title, author byline, created date, content, optional image, and
/// read-only stats, in that order.
class _PostDetailContent extends StatelessWidget {
  const _PostDetailContent({required this.post, required this.commentsStore});

  final Post post;
  final CommentsStore commentsStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = post.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostDetailAuthorRow(post: post),
        const SizedBox(height: AppDimens.spacingMd),
        Text(post.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppDimens.spacingSm),
        if (imageUrl != null) ...[
          _PostDetailImage(post: post, imageUrl: imageUrl),
          const SizedBox(height: AppDimens.spacingMd),
        ],
        Text(post.content, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppDimens.spacingLg),
        _PostDetailStats(post: post),
        const SizedBox(height: AppDimens.spacingLg),
        const Divider(),
        const SizedBox(height: AppDimens.spacingSm),
        CommentsSection(
          store: commentsStore,
          postId: post.id,
          postAuthorId: post.authorId,
        ),
      ],
    );
  }
}

/// The author's avatar, display name, and a relative-to-locale created date.
class _PostDetailAuthorRow extends StatelessWidget {
  const _PostDetailAuthorRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = post.authorPhotoUrl;

    return Row(
      children: [
        Semantics(
          image: true,
          label: "${post.authorName}'s profile photo",
          child: CircleAvatar(
            radius: AppDimens.spacingLg,
            backgroundImage: photoUrl == null
                ? null
                : CachedNetworkImageProvider(photoUrl),
            child: photoUrl == null ? const Icon(Icons.person) : null,
          ),
        ),
        const SizedBox(width: AppDimens.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.authorName, style: theme.textTheme.titleSmall),
              Text(
                DateFormat.yMMMd().add_jm().format(post.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The post's attached image, wrapped in a [Hero] so it animates from
/// [PostCard]'s matching `Hero` in the feed. The tag is derived purely from
/// [Post.id] (`'post-image-${post.id}'`), the exact scheme [PostCard] uses,
/// since [Hero] requires both sides of a transition to share the same tag.
class _PostDetailImage extends StatelessWidget {
  const _PostDetailImage({required this.post, required this.imageUrl});

  final Post post;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'post-image-${post.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: _postDetailImageHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => const SizedBox(
            height: _postDetailImageHeight,
            child: LoadingIndicator(semanticsLabel: 'Loading post image'),
          ),
          errorWidget: (context, url, error) => SizedBox(
            height: _postDetailImageHeight,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The comment count and the tappable [LikeButton] shown at the bottom of
/// the detail page, just above the real `CommentsSection` underneath it.
///
/// The comment count is a plain read-only number, the same as [PostCard]'s
/// own stats row, since [Post.commentsCount] stays accurate even before any
/// page of comments has loaded, and `CommentsSection`'s own loaded thread
/// length is a separate, paginated concern. The like half is a real
/// [LikeButton], backed by a [LikeStore] constructed once per [post] (see
/// [_PostDetailStatsState]) and seeded from [post]'s own
/// [Post.isLikedByMe]/[Post.likesCount], independent of whatever [LikeStore]
/// a [PostCard] for the same post builds for the feed.
class _PostDetailStats extends StatefulWidget {
  const _PostDetailStats({required this.post});

  final Post post;

  @override
  State<_PostDetailStats> createState() => _PostDetailStatsState();
}

class _PostDetailStatsState extends State<_PostDetailStats> {
  late final LikeStore _likeStore = LikeStore(
    isLiked: widget.post.isLikedByMe,
    likesCount: widget.post.likesCount,
    toggleLikeUseCase: getIt<ToggleLikeUseCase>(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.mode_comment_outlined, size: AppDimens.spacingMd),
        const SizedBox(width: AppDimens.spacingXs),
        Text('${widget.post.commentsCount}', style: theme.textTheme.bodyMedium),
        const SizedBox(width: AppDimens.spacingLg),
        LikeButton(store: _likeStore, postId: widget.post.id),
      ],
    );
  }
}

/// The bottom sheet content opened by the floating action button: a
/// [CommentInput] wrapped so it is never hidden behind the on-screen
/// keyboard.
///
/// `showModalBottomSheet` itself is opened with `isScrollControlled: true`
/// by [_PostDetailPageState._openAddCommentSheet]; the remaining half of
/// keyboard-aware layout happens here, wrapping [CommentInput] in a
/// [Padding] sized to [MediaQuery.viewInsetsOf] (the space the keyboard
/// currently occupies) plus a [SafeArea] for the device's own bottom inset
/// (a gesture bar, a notch), so the field and send button stay visible and
/// tappable once the keyboard opens instead of sliding out from under it.
class _AddCommentSheet extends StatelessWidget {
  const _AddCommentSheet({required this.commentsStore, required this.post});

  final CommentsStore commentsStore;
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spacingMd),
          child: CommentInput(
            onSubmit: (content) async {
              await commentsStore.addComment(post.id, content);
              return commentsStore.submitError == null;
            },
          ),
        ),
      ),
    );
  }
}
