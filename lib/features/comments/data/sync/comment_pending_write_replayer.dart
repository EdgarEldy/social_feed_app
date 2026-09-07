import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/pending_write.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/sync/composite_pending_write_replayer.dart';
import '../datasources/comment_local_datasource.dart';
import '../datasources/comment_remote_datasource.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository_impl.dart'
    show commentPendingWriteEntityType;

/// Builds the `entityType: 'comment'` entry [SyncService] uses (through
/// [CompositePendingWriteReplayer]) to replay a queued comment mutation
/// against the real backend once connectivity returns.
///
/// Mirrors `buildPostPendingWriteReplayer` exactly. [payloadJson] on each
/// [PendingWrite] this replays is whatever `CommentRepositoryImpl` encoded
/// when it queued the write; see that class's doc for the exact shape per
/// [PendingWriteOperation]. On a successful replay this also write-throughs
/// the confirmed server response into [localDatasource], the same
/// write-through convention every successful remote read/write in
/// `CommentRepositoryImpl` follows, so the cache does not wait for the next
/// `getComments()` call to catch up. For a replayed create specifically,
/// the client-generated placeholder row (keyed by the `localId`
/// `CommentRepositoryImpl` invented while offline) is deleted first, since
/// it is no longer accurate now that the server has assigned the comment's
/// real id, leaving it in place would otherwise sit alongside the freshly
/// upserted row as a duplicate.
///
/// [SyncService] itself removes the `pending_writes` row once this replayer
/// returns a `Right`; this function has no need to touch `pending_writes`
/// itself (see [SyncService]'s class doc: "a row is removed from
/// `pending_writes` only once its replay succeeds").
EntityPendingWriteReplayer buildCommentPendingWriteReplayer({
  required CommentRemoteDatasource remoteDatasource,
  required CommentLocalDatasource localDatasource,
}) {
  Future<Either<Failure, void>> replay(PendingWrite write) async {
    final payload = jsonDecode(write.payloadJson) as Map<String, dynamic>;
    switch (write.operation) {
      case PendingWriteOperation.create:
        return _replayCreate(remoteDatasource, localDatasource, payload);
      case PendingWriteOperation.update:
        // CommentRepositoryImpl never queues an update: the API Contract
        // has no PATCH /comments/:id endpoint, only POST to create and
        // DELETE to remove one. PendingWriteOperation is a shared enum
        // across every feature, so this branch exists purely for
        // exhaustiveness; a row like this should never actually occur.
        // Returning a Left rather than throwing leaves it queued (and
        // retried on the next reconnect) instead of crashing the drain
        // loop, the same defensive outcome CompositePendingWriteReplayer
        // falls back to for an unregistered entityType.
        return Left(
          CacheFailure('Comments do not support an update operation.'),
        );
      case PendingWriteOperation.delete:
        return _replayDelete(remoteDatasource, localDatasource, payload);
    }
  }

  return EntityPendingWriteReplayer(
    entityType: commentPendingWriteEntityType,
    replay: replay,
  );
}

Future<Either<Failure, void>> _replayCreate(
  CommentRemoteDatasource remoteDatasource,
  CommentLocalDatasource localDatasource,
  Map<String, dynamic> payload,
) async {
  final localId = payload['localId'] as String;
  final result = await remoteDatasource.addComment(
    postId: payload['postId'] as String,
    content: payload['content'] as String,
  );
  if (result is Left<Failure, CommentModel>) {
    return Left(result.value);
  }
  final model = (result as Right<Failure, CommentModel>).value;
  await localDatasource.deleteById(localId);
  await localDatasource.upsert(model);
  return const Right(null);
}

Future<Either<Failure, void>> _replayDelete(
  CommentRemoteDatasource remoteDatasource,
  CommentLocalDatasource localDatasource,
  Map<String, dynamic> payload,
) async {
  final id = payload['id'] as String;
  final result = await remoteDatasource.deleteComment(id);
  if (result is Left<Failure, void>) {
    return Left(result.value);
  }
  await localDatasource.deleteById(id);
  return const Right(null);
}
