import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/pending_write.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_local_datasource.dart';
import '../datasources/comment_remote_datasource.dart';
import '../models/comment_model.dart';

/// The `entity_type` value stamped on every `pending_writes` row this
/// repository queues while offline; [buildCommentPendingWriteReplayer] (in
/// `data/sync/comment_pending_write_replayer.dart`) only reacts to rows
/// carrying this exact value.
const String commentPendingWriteEntityType = 'comment';

/// The signed-in author details [CommentRepositoryImpl] needs to build a
/// locally-plausible placeholder comment while creating one offline; see
/// [_addCommentOffline].
///
/// Mirrors `PostRepositoryImpl`'s own `CurrentAuthorSnapshot` typedef
/// exactly, kept as a separate declaration in this feature rather than an
/// import of the posts one: nothing in the `domain/repositories/*`
/// contracts couples the two features, and `data/` layers are meant to stay
/// composable per-feature, so `feature/comments` should not need to reach
/// into `feature/posts`' `data/` for a plain record shape it can declare
/// itself. `core/di/injection_container.dart`, the composition root,
/// supplies a closure that reads `getIt<AuthStore>().currentUser` and
/// reshapes it into this record, exactly like it already does for
/// `PostRepositoryImpl`.
typedef CurrentAuthorSnapshot = ({
  String id,
  String displayName,
  String? photoUrl,
});

/// Concrete [CommentRepository], coordinating [CommentRemoteDatasource]
/// (`dio`) and [CommentLocalDatasource] (`sqflite`) per the exact same
/// offline-first strategy `PostRepositoryImpl` documents.
///
/// ## Reads: `getComments`
///
/// Follows the same three-step pattern documented on `LocalDatasourceBase`:
/// try the remote call first; on a [NetworkFailure] specifically, fall back
/// to the local cache instead of failing outright; on any other `Failure`
/// (a real response from the backend), surface it as-is. Every successful
/// remote read is written through to the cache before it is returned. The
/// cache fallback has no cursor of its own to page through (the cache
/// stores whatever was last written through, not a full paged history), so
/// it returns every cached comment for the requested post, newest first,
/// with `nextCursor: null`, there is no further page to load from a cache.
///
/// ## Writes: `addComment`/`deleteComment`
///
/// Each write tries the remote call first. A successful remote call is
/// written through to the cache exactly like a read. A [NetworkFailure]
/// specifically, meaning the device is offline rather than the server
/// rejecting the request, triggers the offline-write strategy documented on
/// `SyncService`: a [PendingWrite] row is queued (`entityType: 'comment'`,
/// `operation` matching the call, `payloadJson` encoding whatever the
/// deferred remote call will need) and the same mutation is optimistically
/// applied to the local cache, so the caller sees a `Right` as if the write
/// had succeeded. Any other `Failure` (`ServerFailure`, `UnauthorizedFailure`,
/// ...) is a real answer from the backend and is returned as-is, never
/// queued, queuing a rejected request would just retry the same rejection
/// forever.
///
/// Comments have no update endpoint per the API Contract (only `POST` to
/// create and `DELETE` to remove), so unlike `PostRepositoryImpl` there is
/// no offline-update case here at all.
///
/// ### The offline-create id problem
///
/// `addComment` has no server-assigned id to key the optimistic cache row
/// with, there is no request/response round trip while offline. This class
/// generates a client-side placeholder id (`'local-<timestamp>-<n>'`, see
/// [_nextLocalId]) for that row, and records it in the queued write's
/// `payloadJson` under `localId`, the exact same approach
/// `PostRepositoryImpl._createOffline` established. Once `SyncService`
/// replays the create (`buildCommentPendingWriteReplayer` in
/// `data/sync/comment_pending_write_replayer.dart`), the placeholder row is
/// deleted and replaced by the real server response, so the local-only id
/// never leaks into a `DELETE` call. `deleteComment` against a comment that
/// only exists as an unsynced placeholder (deleting a comment you just
/// added while still offline, before reconnecting) is the same known gap
/// `PostRepositoryImpl` documents for posts: the queued delete would carry
/// the placeholder id, which the backend has never heard of, and fail
/// permanently once replayed.
class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl({
    required this._remoteDatasource,
    required this._localDatasource,
    required this._appDatabase,
    required this._currentAuthor,
  });

  final CommentRemoteDatasource _remoteDatasource;
  final CommentLocalDatasource _localDatasource;
  final AppDatabase _appDatabase;
  final CurrentAuthorSnapshot? Function() _currentAuthor;

  int _localIdSequence = 0;

  @override
  Future<Either<Failure, PaginatedResult<Comment>>> getComments(
    String postId, {
    String? cursor,
    int? limit,
  }) async {
    final remoteResult = await _remoteDatasource.getComments(
      postId,
      cursor: cursor,
      limit: limit,
    );
    if (remoteResult is Left<Failure, PaginatedResult<CommentModel>>) {
      final failure = remoteResult.value;
      if (failure is! NetworkFailure) {
        return Left(failure);
      }
      return _getCommentsFromCache(postId);
    }
    final page =
        (remoteResult as Right<Failure, PaginatedResult<CommentModel>>)
            .value;
    for (final model in page.items) {
      await _localDatasource.upsert(model);
    }
    return Right(
      PaginatedResult(
        items: page.items.map((model) => model.toEntity()).toList(),
        nextCursor: page.nextCursor,
      ),
    );
  }

  Future<Either<Failure, PaginatedResult<Comment>>> _getCommentsFromCache(
    String postId,
  ) async {
    final cacheResult = await _localDatasource.getByPostId(postId);
    if (cacheResult is Left<Failure, List<CommentModel>>) {
      return Left(cacheResult.value);
    }
    final models = (cacheResult as Right<Failure, List<CommentModel>>).value;
    final sorted = [...models]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Right(
      PaginatedResult(
        items: sorted.map((model) => model.toEntity()).toList(),
        nextCursor: null,
      ),
    );
  }

  @override
  Future<Either<Failure, Comment>> addComment({
    required String postId,
    required String content,
  }) async {
    final remoteResult = await _remoteDatasource.addComment(
      postId: postId,
      content: content,
    );
    if (remoteResult is Right<Failure, CommentModel>) {
      final model = remoteResult.value;
      await _localDatasource.upsert(model);
      return Right(model.toEntity());
    }
    final failure = (remoteResult as Left<Failure, CommentModel>).value;
    if (failure is! NetworkFailure) {
      return Left(failure);
    }
    return _addCommentOffline(postId: postId, content: content);
  }

  Future<Either<Failure, Comment>> _addCommentOffline({
    required String postId,
    required String content,
  }) async {
    final author = _currentAuthor();
    final placeholderId = _nextLocalId();
    final placeholder = CommentModel(
      id: placeholderId,
      postId: postId,
      authorId: author?.id ?? '',
      authorName: author?.displayName ?? '',
      authorPhotoUrl: author?.photoUrl,
      content: content,
      createdAt: DateTime.now(),
    );

    await _queuePendingWrite(
      operation: PendingWriteOperation.create,
      payload: {
        'localId': placeholderId,
        'postId': postId,
        'content': content,
      },
    );

    final upsertResult = await _localDatasource.upsert(placeholder);
    if (upsertResult is Left<Failure, void>) {
      return Left(upsertResult.value);
    }
    return Right(placeholder.toEntity());
  }

  @override
  Future<Either<Failure, void>> deleteComment(String id) async {
    final remoteResult = await _remoteDatasource.deleteComment(id);
    if (remoteResult is Left<Failure, void>) {
      final failure = remoteResult.value;
      if (failure is! NetworkFailure) {
        return Left(failure);
      }
      await _queuePendingWrite(
        operation: PendingWriteOperation.delete,
        payload: {'id': id},
      );
      return _localDatasource.deleteById(id);
    }
    await _localDatasource.deleteById(id);
    return const Right(null);
  }

  Future<void> _queuePendingWrite({
    required PendingWriteOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.pendingWritesTable,
      PendingWrite(
        entityType: commentPendingWriteEntityType,
        payloadJson: jsonEncode(payload),
        operation: operation,
        createdAt: DateTime.now(),
      ).toRow(),
    );
  }

  String _nextLocalId() {
    _localIdSequence += 1;
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$_localIdSequence';
  }
}
