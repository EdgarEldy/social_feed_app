import 'package:freezed_annotation/freezed_annotation.dart';

part 'like_model.freezed.dart';
part 'like_model.g.dart';

/// Data-layer response wrappers for the likes endpoints.
///
/// Unlike `UserModel`/`PostModel`/`CommentModel`, neither class here has a
/// `toEntity()`. The API Contract's like endpoints do not return a
/// `Like`-shaped payload (`{ userId, postId, createdAt }`); they return
/// `{ liked, likesCount }` from the toggle and `{ liked }` from the status
/// check, neither of which carries a `userId` or `createdAt` to build a
/// `Like` from. Their consumers, built in `feature/likes`, read `.liked`
/// and `.likesCount` off these directly instead.

/// Response of `POST /posts/:postId/likes`, which toggles the like and
/// reports the resulting state: `{ liked: boolean, likesCount: number }`.
@freezed
abstract class LikeToggleModel with _$LikeToggleModel {
  const factory LikeToggleModel({
    required bool liked,
    required int likesCount,
  }) = _LikeToggleModel;

  factory LikeToggleModel.fromJson(Map<String, dynamic> json) =>
      _$LikeToggleModelFromJson(json);
}

/// Response of `GET /posts/:postId/likes/me`, which reports only whether
/// the signed-in user currently likes the post: `{ liked: boolean }`.
@freezed
abstract class LikeStatusModel with _$LikeStatusModel {
  const factory LikeStatusModel({required bool liked}) = _LikeStatusModel;

  factory LikeStatusModel.fromJson(Map<String, dynamic> json) =>
      _$LikeStatusModelFromJson(json);
}
