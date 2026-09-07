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
import '../../domain/entities/post.dart';
import '../stores/posts_store.dart';

/// The height reserved for a post's attached image on the detail page.
///
/// Taller than [PostCard]'s own `_postImageHeight`, since this page has the
/// whole screen to itself rather than sharing space with a scrolling list of
/// other cards, but the same [BoxFit.cover] keeps the crop behavior (and
/// therefore the [Hero] animation) consistent between the two.
const double _postDetailImageHeight = 260;

/// The full-post screen reached from a [PostCard] tap or a deep link,
/// showing a post's title, content, author, image, and read-only
/// comment/like counts.
///
/// ## Where the [Post] comes from
///
/// [PostCard] already holds the full [Post] it renders, so tapping it pushes
/// this route with that [Post] attached as `extra`, avoiding a redundant
/// `GET /posts/:id` round trip; that is the [initialPost] case. A route
/// reached without that `extra` (a deep link, a cold start restoring this
/// route directly) has no such in-memory [Post], so this page instead calls
/// [PostsStore.loadPost] and renders its loading/error/data observables
/// through an [Observer], the same fallback shape `_EditPostRoute` in
/// `app_router.dart` uses for the edit route.
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

  @override
  void initState() {
    super.initState();
    if (widget.initialPost == null) {
      _postsStore.loadPost(widget.postId);
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

  @override
  Widget build(BuildContext context) {
    final initialPost = widget.initialPost;
    if (initialPost != null) {
      return _PostDetailScaffold(
        post: initialPost,
        onDelete: () => _handleDelete(initialPost),
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
  const _PostDetailScaffold({required this.post, required this.onDelete});

  final Post post;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [_PostDetailAuthorMenu(post: post, onDelete: onDelete)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: _PostDetailContent(post: post),
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
  const _PostDetailContent({required this.post});

  final Post post;

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

/// The read-only comment/like counts shown at the bottom of the detail page.
///
/// Purely decorative numbers on this branch, the same as [PostCard]'s own
/// stats row: `feature/comments` replaces this with a real `CommentsSection`
/// underneath, and `feature/likes` replaces the heart icon with a tappable
/// `LikeButton`.
class _PostDetailStats extends StatelessWidget {
  const _PostDetailStats({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.mode_comment_outlined, size: AppDimens.spacingMd),
        const SizedBox(width: AppDimens.spacingXs),
        Text('${post.commentsCount}', style: theme.textTheme.bodyMedium),
        const SizedBox(width: AppDimens.spacingLg),
        Icon(Icons.favorite_border, size: AppDimens.spacingMd),
        const SizedBox(width: AppDimens.spacingXs),
        Text('${post.likesCount}', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
