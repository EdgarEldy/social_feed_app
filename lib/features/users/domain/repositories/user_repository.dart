import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user.dart';

/// Contract for the user profile endpoints in the API Contract:
/// `GET /users/:id`, `PATCH /users/me` and `POST /users/me/avatar`.
///
/// `User` is defined under `features/auth/domain/entities/user.dart`
/// rather than duplicated here: it is the same entity returned by
/// `/auth/register` and `/auth/login`, and this feature only adds ways to
/// read and edit it.
abstract class UserRepository {
  /// Calls `GET /users/:id`.
  Future<Either<Failure, User>> getUser(String id);

  /// Calls `PATCH /users/me` with `{ displayName? }`.
  Future<Either<Failure, User>> updateCurrentUser({String? displayName});

  /// Calls `POST /users/me/avatar` as a multipart upload and returns the
  /// resulting `photoUrl`.
  ///
  /// `File` is used directly, matching the established exception in
  /// README's `createPost(Post post, {File? image})` example: `domain/`
  /// otherwise avoids platform-specific imports, but `dart:io`'s `File` is
  /// the one precedent already set for representing a picked image.
  Future<Either<Failure, String>> uploadAvatar(File image);
}
