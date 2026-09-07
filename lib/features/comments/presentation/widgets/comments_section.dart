import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../stores/comments_store.dart';
import 'comment_tile.dart';

/// The comment thread embedded inside `PostDetailPage`'s own scrollable
/// content: a heading, one `CommentTile` per `CommentsStore.comments`, the
/// loading/empty/error states for the initial load, and a small trailing
/// spinner while `CommentsStore.loadMore` fetches the next page.
///
/// Takes [store] as a constructor parameter rather than resolving one from
/// `get_it` itself: `CommentsStore` is scoped per `PostDetailPage` (see that
/// store's own class doc), so `PostDetailPage` owns the single instance and
/// this widget only ever observes it.
///
/// ## Why `ListView.builder` with disabled physics, not its own scroll view
///
/// `PostDetailPage` already wraps its whole body in one
/// `SingleChildScrollView`; this section is a piece of that body, not a
/// second independent scrollable surface. Giving it its own scrolling
/// `ListView` would nest two scrollables inside each other, which either
/// throws an unbounded-height layout error or, once worked around, fights
/// the outer scroll view over drag gestures. `shrinkWrap: true` lets this
/// `ListView` size itself to its children instead of expanding to fill an
/// unbounded height, and `NeverScrollableScrollPhysics` hands every drag
/// back to the outer `SingleChildScrollView`, so the page scrolls as one
/// surface with the comments simply laid out inline partway down it.
/// Pagination is driven from the outside instead: `PostDetailPage` owns the
/// `ScrollController` on its own `SingleChildScrollView` and calls
/// `CommentsStore.loadMore` once the user scrolls near the bottom of the
/// whole page, the same threshold-based pattern `FeedPage` uses for posts.
class CommentsSection extends StatelessWidget {
  const CommentsSection({
    super.key,
    required this.store,
    required this.postId,
    required this.postAuthorId,
  });

  /// The comment thread being rendered.
  final CommentsStore store;

  /// The post this thread belongs to, forwarded to `CommentTile` for its own
  /// `CommentsStore.deleteComment` call.
  final String postId;

  /// The id of the post's author, forwarded to `CommentTile` to decide
  /// delete-button visibility per the author-or-post-author business rule.
  final String postAuthorId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Observer(
      builder: (_) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comments', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.spacingSm),
            ..._buildBody(theme, store),
          ],
        );
      },
    );
  }

  List<Widget> _buildBody(ThemeData theme, CommentsStore store) {
    if (store.isLoading && !store.hasLoadedOnce) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimens.spacingLg),
          child: LoadingIndicator(semanticsLabel: 'Loading comments'),
        ),
      ];
    }

    final error = store.error;
    if (error != null && store.comments.isEmpty) {
      return [
        ErrorView(
          message: error.message,
          onRetry: () => store.loadComments(postId),
        ),
      ];
    }

    if (store.hasLoadedOnce && store.comments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingLg),
          child: Text(
            'No comments yet. Be the first to say something.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: store.comments.length,
        itemBuilder: (context, index) {
          final comment = store.comments[index];
          return CommentTile(
            comment: comment,
            postAuthorId: postAuthorId,
            postId: postId,
            store: store,
          );
        },
      ),
      if (store.isLoadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimens.spacingMd),
          child: LoadingIndicator(semanticsLabel: 'Loading more comments'),
        ),
    ];
  }
}
