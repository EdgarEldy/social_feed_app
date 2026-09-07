import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/pending_write.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/sync/composite_pending_write_replayer.dart';
import '../datasources/post_local_datasource.dart';
import '../datasources/post_remote_datasource.dart';
import '../models/post_model.dart';
import '../repositories/post_repository_impl.dart' show postPendingWriteEntityType;

/// Builds the `entityType: 'post'` entry [SyncService] uses (through
/// [CompositePendingWriteReplayer]) to replay a queued post mutation
/// against the real backend once connectivity returns.
///
/// [payloadJson] on each [PendingWrite] this replays is whatever
/// `PostRepositoryImpl` encoded when it queued the write; see that class's
/// doc for the exact shape per [PendingWriteOperation]. On a successful
/// replay this also write-throughs the confirmed server response into
/// [localDatasource], the same write-through convention every successful
/// remote read/write in `PostRepositoryImpl` follows, so the cache does not
/// wait for the next `getPosts()`/`getPost()` call to catch up. For a
/// replayed create specifically, the client-generated placeholder row
/// (keyed by the `localId` PostRepositoryImpl invented while offline) is
/// deleted first, since it is no longer accurate now that the server has
/// assigned the post's real id, leaving it in place would otherwise sit
/// alongside the freshly upserted row as a duplicate.
///
/// [SyncService] itself removes the `pending_writes` row once this replayer
/// returns a `Right`; this function has no need to touch `pending_writes`
/// itself (see [SyncService]'s class doc: "a row is removed from
/// `pending_writes` only once its replay succeeds").
EntityPendingWriteReplayer buildPostPendingWriteReplayer({
  required PostRemoteDatasource remoteDatasource,
  required PostLocalDatasource localDatasource,
}) {
  Future<Either<Failure, void>> replay(PendingWrite write) async {
    final payload = jsonDecode(write.payloadJson) as Map<String, dynamic>;
    switch (write.operation) {
      case PendingWriteOperation.create:
        return _replayCreate(remoteDatasource, localDatasource, payload);
      case PendingWriteOperation.update:
        return _replayUpdate(remoteDatasource, localDatasource, payload);
      case PendingWriteOperation.delete:
        return _replayDelete(remoteDatasource, localDatasource, payload);
    }
  }

  return EntityPendingWriteReplayer(
    entityType: postPendingWriteEntityType,
    replay: replay,
  );
}

Future<Either<Failure, void>> _replayCreate(
  PostRemoteDatasource remoteDatasource,
  PostLocalDatasource localDatasource,
  Map<String, dynamic> payload,
) async {
  final localId = payload['localId'] as String;
  final imagePath = payload['imagePath'] as String?;
  final result = await remoteDatasource.createPost(
    title: payload['title'] as String,
    content: payload['content'] as String,
    image: imagePath == null ? null : File(imagePath),
  );
  if (result is Left<Failure, PostModel>) {
    return Left(result.value);
  }
  final model = (result as Right<Failure, PostModel>).value;
  await localDatasource.deleteById(localId);
  await localDatasource.upsert(model);
  return const Right(null);
}

Future<Either<Failure, void>> _replayUpdate(
  PostRemoteDatasource remoteDatasource,
  PostLocalDatasource localDatasource,
  Map<String, dynamic> payload,
) async {
  final result = await remoteDatasource.updatePost(
    payload['id'] as String,
    title: payload['title'] as String?,
    content: payload['content'] as String?,
  );
  if (result is Left<Failure, PostModel>) {
    return Left(result.value);
  }
  final model = (result as Right<Failure, PostModel>).value;
  await localDatasource.upsert(model);
  return const Right(null);
}

Future<Either<Failure, void>> _replayDelete(
  PostRemoteDatasource remoteDatasource,
  PostLocalDatasource localDatasource,
  Map<String, dynamic> payload,
) async {
  final id = payload['id'] as String;
  final result = await remoteDatasource.deletePost(id);
  if (result is Left<Failure, void>) {
    return Left(result.value);
  }
  await localDatasource.deleteById(id);
  return const Right(null);
}
