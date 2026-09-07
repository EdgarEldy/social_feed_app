import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user.dart';
import '../repositories/user_repository.dart';

/// Looks up a single user profile by id.
///
/// A thin pass-through to `UserRepository.getUser`; kept as its own usecase
/// rather than calling the repository directly from `UserStore` so the
/// presentation layer only ever depends on `domain/`, per the architecture
/// rule that stores call usecases, not repositories.
class GetUserUseCase {
  GetUserUseCase({required this._userRepository});

  final UserRepository _userRepository;

  /// Calls `GET /users/:id`.
  Future<Either<Failure, User>> call(String id) {
    return _userRepository.getUser(id);
  }
}
