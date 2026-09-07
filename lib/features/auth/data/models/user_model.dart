import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Data-layer counterpart of [User], adding JSON (de)serialization for the
/// `User` shape returned by `/auth/register`, `/auth/login`, `GET /users/:id`
/// and `PATCH /users/me`:
/// `{ id, displayName, email, photoUrl, createdAt }`.
///
/// `freezed`-generated classes cannot extend a plain entity class the way a
/// hand-written model could, so `UserModel` maps onto [User] explicitly via
/// [toEntity] instead of inheriting from it. Only `data/` ever imports this
/// class; `domain/` and `presentation/` only ever see the plain [User] it
/// converts to.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String displayName,
    required String email,
    String? photoUrl,
    required DateTime createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Maps this wire model onto the domain [User] entity.
  User toEntity() {
    return User(
      id: id,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      createdAt: createdAt,
    );
  }
}
