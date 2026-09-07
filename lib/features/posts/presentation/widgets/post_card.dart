import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/stores/auth_store.dart';
import '../../domain/entities/post.dart';
import '../stores/posts_store.dart';

/// The fade/slide-in duration used the first time a [PostCard] appears on
/// screen.
const Duration _postCardAppearDuration = Duration(milliseconds: 250);

/// The height reserved for a post's attached image, when it has one.
const double _postImageHeight = 180;

/// A single feed item: author byline, title, a truncated content preview,
/// the post image (if any), and read-only comment/like counts.
///
/// Built on [AppCard] so every card in the feed shares this app's standard
/// padding and corner radius rather than a bespoke layout. Tapping anywhere
/// on the card (outside the author-only menu) pushes `/posts/:id` via
/// `context.push`, not `context.go`, so the feed stays on the navigation
/// stack underneath `PostDetailPage`, passing [post] itself as `extra` so
/// `PostDetailPage` does not need a redundant `GET /posts/:id` for a post
/// this card already has in memory.
///
/// The comment/like counts rendered here are decorative numbers only; the
/// tappable comment/like interactions belong to `feature/comments` and
/// `feature/likes`, later branches.
///
/// Fades and slides in the first time it appears, see [_PostCardState].
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});

  /// The post this card renders.
  final Post post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Flipping this in initState itself would make the very first build
    // already show the "visible" state, since AnimatedOpacity/AnimatedSlide
    // only animate a change between two builds, not an initial value. A
    // post-frame callback lets the first build render the "hidden" state,
    // then flips it on the very next frame so the transition actually plays.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: _postCardAppearDuration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: _postCardAppearDuration,
        curve: Curves.easeOut,
        child: AppCard(
          onTap: () =>
              context.push('/posts/${widget.post.id}', extra: widget.post),
          child: _PostCardContent(post: widget.post),
        ),
      ),
    );
  }
}

/// The card's inner layout: author header, title, content preview, optional
/// image, and the comment/like counts.
///
/// Split out from [PostCard] so the [StatefulWidget] above stays focused on
/// the appear animation, keeping both widgets well under the ~150 line
/// guideline.
class _PostCardContent extends StatelessWidget {
  const _PostCardContent({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = post.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostAuthorHeader(post: post),
        const SizedBox(height: AppDimens.spacingSm),
        Text(post.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDimens.spacingXs),
        Text(
          post.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        if (imageUrl != null) ...[
          const SizedBox(height: AppDimens.spacingSm),
          _PostImage(post: post, imageUrl: imageUrl),
        ],
        const SizedBox(height: AppDimens.spacingSm),
        _PostStats(post: post),
      ],
    );
  }
}

/// The author's avatar and display name, plus an edit/delete menu shown
/// only when the signed-in user authored [post].
///
/// Wrapped in its own [Observer] so a sign-out mid-scroll (an edge case, but
/// a real one: [AuthStore.currentUser] can change under an already-built
/// feed) re-evaluates the "am I the author" check without re-running the
/// rest of the card's layout.
class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = post.authorPhotoUrl;

    return Observer(
      builder: (_) {
        final isAuthor =
            getIt<AuthStore>().currentUser?.id == post.authorId;
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
                child: photoUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            const SizedBox(width: AppDimens.spacingSm),
            Expanded(
              child: Text(
                post.authorName,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAuthor) _PostAuthorMenu(post: post),
          ],
        );
      },
    );
  }
}

/// The edit/delete affordance shown only to a post's own author.
///
/// Edit navigates to `/posts/:id/edit`, passing [post] itself as `extra` so
/// `CreatePostPage` (in its edit mode, see the class doc on
/// `_PostAuthorMenu`'s companion, `CreatePostPage`, for the reuse-vs-new-page
/// decision) does not need to refetch a post this card already has in
/// memory. Delete calls [PostsStore.deletePost] directly, which removes the
/// post from the feed on success.
class _PostAuthorMenu extends StatelessWidget {
  const _PostAuthorMenu({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Post actions',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            context.push('/posts/${post.id}/edit', extra: post);
          case 'delete':
            getIt<PostsStore>().deletePost(post.id);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

/// The post's attached image, loaded with [CachedNetworkImage].
///
/// Shows a [LoadingIndicator] while the image downloads and a broken-image
/// icon if it fails to load, per this branch's requirement to render images
/// with `CachedNetworkImage`'s own `placeholder`/`errorWidget` builders.
///
/// Wrapped in a [Hero] tagged `'post-image-${post.id}'`, the exact scheme
/// `PostDetailPage`'s own image uses, so tapping a card with an image
/// animates it into the detail page's larger image instead of the detail
/// page's content just appearing underneath it. Keeping the same [BoxFit]
/// (`cover`) between the two, even though the two heights differ, is what
/// keeps that animation from visibly snapping at the very end.
class _PostImage extends StatelessWidget {
  const _PostImage({required this.post, required this.imageUrl});

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
          height: _postImageHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => const SizedBox(
            height: _postImageHeight,
            child: LoadingIndicator(semanticsLabel: 'Loading post image'),
          ),
          errorWidget: (context, url, error) => SizedBox(
            height: _postImageHeight,
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

/// The read-only comment/like counts shown at the bottom of a [PostCard].
///
/// Purely decorative numbers for this branch; tapping to comment or like
/// arrives with `feature/comments`/`feature/likes`.
class _PostStats extends StatelessWidget {
  const _PostStats({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.mode_comment_outlined, size: AppDimens.spacingMd),
        const SizedBox(width: AppDimens.spacingXs),
        Text('${post.commentsCount}', style: theme.textTheme.bodySmall),
        const SizedBox(width: AppDimens.spacingMd),
        Icon(Icons.favorite_border, size: AppDimens.spacingMd),
        const SizedBox(width: AppDimens.spacingXs),
        Text('${post.likesCount}', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
