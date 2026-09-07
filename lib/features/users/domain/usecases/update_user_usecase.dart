import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user.dart';
import '../repositories/user_repository.dart';

/// Updates the signed-in user's editable profile fields.
///
/// `displayName` is the only field `PATCH /users/me` accepts per the API
/// Contract, so this usecase is a thin pass-through to
/// `UserRepository.updateCurrentUser`; leaving it `null` means "no change"
/// and is forwarded to the repository unchanged rather than validated here.
class UpdateUserUseCase {
  UpdateUserUseCase({required this._userRepository});

  final UserRepository _userRepository;

  /// Calls `PATCH /users/me` with `{ displayName? }`.
  Future<Either<Failure, User>> call({String? displayName}) {
    return _userRepository.updateCurrentUser(displayName: displayName);
  }
}
