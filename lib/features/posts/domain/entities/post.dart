import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';

/// A single feed post, with the author details denormalized onto it so the
/// feed and detail screens never need a separate `User` lookup per post.
///
/// Mirrors the `Post` shape returned by `GET /posts`, `GET /posts/:id`,
/// `POST /posts` and `PATCH /posts/:id`. Pure domain entity: no `dio`, no
/// `sqflite`, no Flutter import, no JSON knowledge (that is `PostModel`'s
/// job in `data/models/post_model.dart`).
///
/// Built with `freezed` for free value equality and `copyWith`, used by
/// usecases such as editing a post (`title`/`content`) and by the likes
/// feature to reconcile optimistic `likesCount`/`isLikedByMe` updates with
/// the server response.
@freezed
abstract class Post with _$Post {
  const factory Post({
    /// Server-assigned unique identifier.
    required String id,

    /// Id of the `User` who authored the post.
    required String authorId,

    /// The author's display name at the time the post was fetched,
    /// denormalized so the feed can render an author byline without a
    /// separate `User` call.
    required String authorName,

    /// The author's avatar URL, denormalized for the same reason as
    /// `authorName`. `null` if the author has no avatar set.
    String? authorPhotoUrl,

    required String title,

    required String content,

    /// URL of the post's attached image, or `null` for a text-only post.
    String? imageUrl,

    required DateTime createdAt,

    /// When the post was last edited via `PATCH /posts/:id`, or `null` if
    /// it has never been edited.
    DateTime? updatedAt,

    required int commentsCount,

    required int likesCount,

    /// Whether the currently signed-in user has liked this post.
    ///
    /// Per the Domain Model section, this is never client-derived state; it
    /// comes straight from the API, either inline on `GET /posts` or via a
    /// separate `GET /posts/:id/likes/me` call for a single post's detail
    /// page.
    required bool isLikedByMe,
  }) = _Post;
}
