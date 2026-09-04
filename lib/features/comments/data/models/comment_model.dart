import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/comment.dart';

part 'comment_model.freezed.dart';
part 'comment_model.g.dart';

/// Data-layer counterpart of [Comment], adding JSON (de)serialization for
/// the `Comment` shape returned by `GET /posts/:postId/comments` and
/// `POST /posts/:postId/comments`.
///
/// `freezed`-generated classes cannot extend a plain entity class, so
/// `CommentModel` maps onto [Comment] explicitly via [toEntity] instead of
/// inheriting from it, for the same reason as `UserModel`.
@freezed
abstract class CommentModel with _$CommentModel {
  const CommentModel._();

  const factory CommentModel({
    required String id,
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String content,
    required DateTime createdAt,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);

  /// Maps this wire model onto the domain [Comment] entity.
  Comment toEntity() {
    return Comment(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      content: content,
      createdAt: createdAt,
    );
  }
}
