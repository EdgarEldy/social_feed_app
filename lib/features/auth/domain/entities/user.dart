import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// A registered user of the app.
///
/// Mirrors the `User` shape returned by the API across every endpoint that
/// includes one: `POST /auth/register`, `POST /auth/login`, `GET /users/:id`
/// and `PATCH /users/me`. This is a pure domain entity: no `dio`, no
/// `sqflite`, no Flutter import, and no JSON knowledge, that belongs to
/// `UserModel` in `data/models/user_model.dart`.
///
/// Built with `freezed` for free value equality and `copyWith`. This stays
/// domain-pure because `freezed_annotation` is a plain-Dart annotation
/// package with no Flutter/`dio`/`sqflite` dependency, the same precedent
/// already set by `fpdart`'s `Either` in `domain/`; the JSON annotations
/// live only on `UserModel` in `data/`.
@freezed
abstract class User with _$User {
  const factory User({
    /// Server-assigned unique identifier.
    required String id,

    /// The name shown across the app; editable via `PATCH /users/me`.
    required String displayName,

    /// The account's email address.
    required String email,

    /// URL of the user's avatar, or `null` until one is uploaded via
    /// `POST /users/me/avatar`.
    String? photoUrl,

    /// When the account was created.
    required DateTime createdAt,
  }) = _User;
}
