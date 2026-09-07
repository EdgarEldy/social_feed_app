import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/post.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

/// Data-layer counterpart of [Post], adding JSON (de)serialization for the
/// `Post` shape returned by `GET /posts`, `GET /posts/:id`, `POST /posts`
/// and `PATCH /posts/:id`.
///
/// `freezed`-generated classes cannot extend a plain entity class, so
/// `PostModel` maps onto [Post] explicitly via [toEntity] instead of
/// inheriting from it, for the same reason as `UserModel`.
@freezed
abstract class PostModel with _$PostModel {
  const PostModel._();

  const factory PostModel({
    required String id,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String title,
    required String content,
    String? imageUrl,
    required DateTime createdAt,
    DateTime? updatedAt,
    required int commentsCount,
    required int likesCount,
    // Per the Domain Model section, `isLikedByMe` is ideally always present
    // on `GET /posts`, but a backend that only supports the separate
    // `GET /posts/:id/likes/me` lookup may omit it entirely on list
    // responses, so this defaults to `false` rather than requiring the key.
    @Default(false) bool isLikedByMe,
  }) = _PostModel;

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);

  /// Maps this wire model onto the domain [Post] entity.
  Post toEntity() {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      title: title,
      content: content,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      commentsCount: commentsCount,
      likesCount: likesCount,
      isLikedByMe: isLikedByMe,
    );
  }
}
