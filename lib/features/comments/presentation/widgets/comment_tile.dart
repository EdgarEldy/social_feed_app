import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/stores/auth_store.dart';
import '../../domain/entities/comment.dart';
import '../stores/comments_store.dart';

/// A single row in `CommentsSection`: author avatar, name, content, a
/// `timeago`-formatted relative timestamp, and a delete affordance shown
/// only when the signed-in user is allowed to remove [comment].
///
/// ## Delete visibility: author-or-post-author, not author-only
///
/// `PostCard`/`PostDetailPage` hide their own edit/delete menu unless the
/// signed-in user authored the post. Comments follow a *different* business
/// rule per this branch's task list: a comment can be deleted by whoever
/// wrote it, or by whoever authored the post it is attached to (moderating
/// their own thread). That is why this widget takes [postAuthorId]
/// separately, a plain id rather than the whole `Post` entity, since
/// nothing else about this tile needs the containing post.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.postAuthorId,
    required this.postId,
    required this.store,
  });

  /// The comment this row renders.
  final Comment comment;

  /// The id of the author of the post [comment] belongs to, used alongside
  /// [Comment.authorId] to decide whether the signed-in user may delete it.
  final String postAuthorId;

  /// The id of the post [comment] belongs to, passed through to
  /// [CommentsStore.deleteComment] so it can refetch the right thread.
  final String postId;

  /// The store backing the enclosing `CommentsSection`, used directly for
  /// [CommentsStore.deleteComment] rather than routed back up through a
  /// callback, since deletion is a store action, not new information this
  /// tile discovers itself (unlike `CommentInput`'s typed text).
  final CommentsStore store;

  Future<void> _handleDelete(BuildContext context) async {
    await store.deleteComment(comment.id, postId);
    if (!context.mounted) return;
    final error = store.deleteError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = comment.authorPhotoUrl;

    return Observer(
      builder: (_) {
        final currentUserId = getIt<AuthStore>().currentUser?.id;
        final canDelete = currentUserId != null &&
            (currentUserId == comment.authorId ||
                currentUserId == postAuthorId);
        final isDeleting = store.deletingCommentId == comment.id;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                image: true,
                label: "${comment.authorName}'s profile photo",
                child: CircleAvatar(
                  radius: AppDimens.spacingMd,
                  backgroundImage: photoUrl == null
                      ? null
                      : CachedNetworkImageProvider(photoUrl),
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: AppDimens.spacingMd)
                      : null,
                ),
              ),
              const SizedBox(width: AppDimens.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.authorName,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeago.format(comment.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spacingXs),
                    Text(comment.content, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (canDelete)
                isDeleting
                    ? const Padding(
                        padding: EdgeInsets.all(AppDimens.spacingSm),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _handleDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete comment',
                      ),
            ],
          ),
        );
      },
    );
  }
}
