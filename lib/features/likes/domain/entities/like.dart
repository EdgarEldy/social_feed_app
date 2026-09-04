import 'package:freezed_annotation/freezed_annotation.dart';

part 'like.freezed.dart';

/// The relationship between a `User` and a `Post` they have liked.
///
/// Per the Domain Model section of the README, this is the conceptual join
/// entity between `users` and `posts`. The API Contract's like endpoints do
/// not currently return this shape directly (see `LikeToggleModel` and
/// `LikeStatusModel` in `data/models/like_model.dart`); it is kept here as
/// the domain-level representation of "this user likes this post" for use
/// by future usecases and for symmetry with the rest of the domain model.
///
/// Pure domain entity: no `dio`, no `sqflite`, no Flutter import, no JSON
/// knowledge. Built with `freezed` for free value equality and `copyWith`,
/// consistent with the other entities.
@freezed
abstract class Like with _$Like {
  const factory Like({
    /// Id of the `User` who liked the post.
    required String userId,

    /// Id of the `Post` that was liked.
    required String postId,

    required DateTime createdAt,
  }) = _Like;
}
