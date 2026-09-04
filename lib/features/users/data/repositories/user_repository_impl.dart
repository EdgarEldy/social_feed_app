import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';

/// Concrete [UserRepository], delegating to [UserRemoteDatasource].
///
/// There is no local datasource here, unlike `PostRepositoryImpl`/
/// `CommentRepositoryImpl`: a user profile read/write has no meaningful
/// cached fallback for this branch's scope, so this class only translates
/// [UserRemoteDatasource]'s data-layer return shapes (a `UserModel`, a raw
/// `photoUrl` `String`) into the domain-level `Either<Failure, T>` shapes
/// [UserRepository] declares, mapping the wire-level `UserModel` onto the
/// domain `User` via `toEntity()` along the way.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remoteDatasource);

  final UserRemoteDatasource _remoteDatasource;

  @override
  Future<Either<Failure, User>> getUser(String id) async {
    final result = await _remoteDatasource.getUser(id);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, User>> updateCurrentUser({
    String? displayName,
  }) async {
    final result = await _remoteDatasource.updateCurrentUser(
      displayName: displayName,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(
    File image, {
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _remoteDatasource.uploadAvatar(
      image,
      onSendProgress: onSendProgress,
    );
  }
}
