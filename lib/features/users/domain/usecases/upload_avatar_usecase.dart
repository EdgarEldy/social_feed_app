import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/user_repository.dart';

/// Uploads a new avatar image for the signed-in user.
///
/// A thin pass-through to `UserRepository.uploadAvatar`, which returns the
/// resulting `photoUrl` rather than a full `User`, matching `POST
/// /users/me/avatar`'s response shape in the API Contract. Reconciling that
/// `photoUrl` with the rest of the profile (e.g. updating `AuthStore`'s
/// cached `currentUser`) is the caller's job, not this usecase's.
class UploadAvatarUseCase {
  UploadAvatarUseCase({required this._userRepository});

  final UserRepository _userRepository;

  /// Calls `POST /users/me/avatar` with the given image file.
  ///
  /// [onSendProgress] is forwarded to `UserRepository.uploadAvatar`; see its
  /// doc for what it drives.
  Future<Either<Failure, String>> call(
    File image, {
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _userRepository.uploadAvatar(image, onSendProgress: onSendProgress);
  }
}
