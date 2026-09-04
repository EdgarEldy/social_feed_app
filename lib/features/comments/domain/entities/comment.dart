import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';

/// A single comment on a `Post`, with the author details denormalized onto
/// it for the same reason as `Post.authorName`/`Post.authorPhotoUrl`: it
/// lets `CommentTile` render without a separate `User` lookup per comment.
///
/// Mirrors the `Comment` shape returned by `GET /posts/:postId/comments`
/// and `POST /posts/:postId/comments`. Pure domain entity: no `dio`, no
/// `sqflite`, no Flutter import, no JSON knowledge (that is `CommentModel`'s
/// job in `data/models/comment_model.dart`).
///
/// Built with `freezed`, which also gives a `copyWith` for free even though
/// nothing in this branch currently needs one: the API Contract has no
/// endpoint to edit a comment, only `POST` to create and `DELETE` to remove
/// one.
@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    /// Server-assigned unique identifier.
    required String id,

    /// Id of the `Post` this comment belongs to.
    required String postId,

    /// Id of the `User` who authored the comment.
    required String authorId,

    /// The author's display name at the time the comment was fetched.
    required String authorName,

    /// The author's avatar URL, or `null` if the author has no avatar set.
    String? authorPhotoUrl,

    required String content,

    required DateTime createdAt,
  }) = _Comment;
}
