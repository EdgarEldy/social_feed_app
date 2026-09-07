import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/repositories/like_repository.dart';
import '../datasources/like_remote_datasource.dart';

/// Concrete [LikeRepository], delegating directly to [LikeRemoteDatasource].
///
/// There is no local datasource and no offline coordination here at all,
/// unlike `PostRepositoryImpl`/`CommentRepositoryImpl`: this branch's task
/// list does not call for caching a like status or queueing a toggle made
/// while offline, likes are live-only. This class only reshapes
/// [LikeRemoteDatasource]'s data-layer response DTOs
/// ([LikeToggleModel]/[LikeStatusModel]) into the plain record/bool shapes
/// [LikeRepository] declares.
class LikeRepositoryImpl implements LikeRepository {
  LikeRepositoryImpl(this._remoteDatasource);

  final LikeRemoteDatasource _remoteDatasource;

  @override
  Future<Either<Failure, ({bool liked, int likesCount})>> toggleLike(
    String postId,
  ) async {
    final result = await _remoteDatasource.toggleLike(postId);
    return result.map(
      (model) => (liked: model.liked, likesCount: model.likesCount),
    );
  }

  @override
  Future<Either<Failure, bool>> getLikeStatus(String postId) async {
    final result = await _remoteDatasource.getLikeStatus(postId);
    return result.map((model) => model.liked);
  }
}
