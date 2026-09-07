import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/pending_write.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_local_datasource.dart';
import '../datasources/post_remote_datasource.dart';
import '../models/post_model.dart';

/// The `entity_type` value stamped on every `pending_writes` row this
/// repository queues while offline; [buildPostPendingWriteReplayer] (in
/// `data/sync/post_pending_write_replayer.dart`) only reacts to rows
/// carrying this exact value.
const String postPendingWriteEntityType = 'post';

/// The signed-in author details [PostRepositoryImpl] needs to build a
/// locally-plausible placeholder post while creating one offline; see
/// [_createOffline].
///
/// A plain record, not the domain `User`, so this stays a purely structural
/// shape: `data/` reading `presentation/`'s `AuthStore` directly would break
/// the dependency rule (`presentation/` depends on `domain/`, never the
/// other way around), so `PostRepositoryImpl` never imports `AuthStore`
/// itself. Instead `core/di/injection_container.dart`, the composition
/// root, supplies a closure that reads `getIt<AuthStore>().currentUser` and
/// reshapes it into this record, the same "resolve a presentation-layer
/// singleton lazily from a closure built at the composition root" pattern
/// already used for `DioClient.create`'s `onSessionExpired` callback.
typedef CurrentAuthorSnapshot = ({String id, String displayName, String? photoUrl});

/// Concrete [PostRepository], coordinating [PostRemoteDatasource] (`dio`)
/// and [PostLocalDatasource] (`sqflite`) per the offline-first strategy
/// documented on [LocalDatasourceBase]'s class doc.
///
/// ## Reads: `getPosts`/`getPost`
///
/// Both follow the three-step pattern documented on `LocalDatasourceBase`:
/// try the remote call first; on a [NetworkFailure] specifically, fall back
/// to the local cache instead of failing outright; on any other `Failure`
/// (a real response from the backend), surface it as-is. Every successful
/// remote read is written through to the cache before it is returned.
/// [getPosts]'s cache fallback has no cursor of its own to page through
/// (the cache stores whatever was last written through, not a full paged
/// history), so it returns every cached post, newest first, with
/// `nextCursor: null`, there is no further page to load from a cache.
///
/// ## Writes: `createPost`/`updatePost`/`deletePost`
///
/// Each write tries the remote call first. A successful remote call is
/// written through to the cache exactly like a read. A [NetworkFailure]
/// specifically, meaning the device is offline rather than the server
/// rejecting the request, triggers the offline-write strategy documented on
/// `SyncService`: a [PendingWrite] row is queued (`entityType: 'post'`,
/// `operation` matching the call, `payloadJson` encoding whatever the
/// deferred remote call will need) and the same mutation is optimistically
/// applied to the local cache, so the caller sees a `Right` as if the write
/// had succeeded. Any other `Failure` (`ServerFailure`, `UnauthorizedFailure`,
/// ...) is a real answer from the backend and is returned as-is, never
/// queued, queuing a rejected request would just retry the same rejection
/// forever.
///
/// ### The offline-create id problem
///
/// `createPost` has no server-assigned id to key the optimistic cache row
/// with, there is no request/response round trip while offline. This class
/// generates a client-side placeholder id (`'local-<timestamp>-<n>'`, see
/// [_nextLocalId]) for that row, and records it in the queued write's
/// `payloadJson` under `localId`. Once `SyncService` replays the create
/// (`buildPostPendingWriteReplayer` in
/// `data/sync/post_pending_write_replayer.dart`), the placeholder row is
/// deleted and replaced by the real server response, so the local-only id
/// never leaks into a `PATCH`/`DELETE` call. `updatePost`/`deletePost`
/// against a post that only exists as an unsynced placeholder (editing a
/// post you just created while still offline, before reconnecting) is a
/// known gap this branch does not attempt to solve: the queued update/delete
/// would carry the placeholder id, which the backend has never heard of, and
/// fail permanently once replayed. Handling that chain correctly needs the
/// sync queue to itself understand id remapping across dependent writes,
/// which is out of scope for the offline-write strategy as documented on
/// `SyncService` today.
class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({
    required this._remoteDatasource,
    required this._localDatasource,
    required this._appDatabase,
    required this._currentAuthor,
  });

  final PostRemoteDatasource _remoteDatasource;
  final PostLocalDatasource _localDatasource;
  final AppDatabase _appDatabase;
  final CurrentAuthorSnapshot? Function() _currentAuthor;

  int _localIdSequence = 0;

  @override
  Future<Either<Failure, PaginatedResult<Post>>> getPosts({
    String? cursor,
    int? limit,
  }) async {
    final remoteResult = await _remoteDatasource.getPosts(
      cursor: cursor,
      limit: limit,
    );
    if (remoteResult is Left<Failure, PaginatedResult<PostModel>>) {
      final failure = remoteResult.value;
      if (failure is! NetworkFailure) {
        return Left(failure);
      }
      return _getPostsFromCache();
    }
    final page = (remoteResult as Right<Failure, PaginatedResult<PostModel>>)
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

  Future<Either<Failure, PaginatedResult<Post>>> _getPostsFromCache() async {
    final cacheResult = await _localDatasource.getAll();
    if (cacheResult is Left<Failure, List<PostModel>>) {
      return Left(cacheResult.value);
    }
    final models = (cacheResult as Right<Failure, List<PostModel>>).value;
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
  Future<Either<Failure, Post>> getPost(String id) async {
    final remoteResult = await _remoteDatasource.getPost(id);
    if (remoteResult is Left<Failure, PostModel>) {
      final failure = remoteResult.value;
      if (failure is! NetworkFailure) {
        return Left(failure);
      }
      final cacheResult = await _localDatasource.getById(id);
      if (cacheResult is Left<Failure, PostModel?>) {
        return Left(cacheResult.value);
      }
      final cached = (cacheResult as Right<Failure, PostModel?>).value;
      if (cached == null) {
        return Left(CacheFailure('No cached post for id $id.'));
      }
      return Right(cached.toEntity());
    }
    final model = (remoteResult as Right<Failure, PostModel>).value;
    await _localDatasource.upsert(model);
    return Right(model.toEntity());
  }

  @override
  Future<Either<Failure, Post>> createPost({
    required String title,
    required String content,
    File? image,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final remoteResult = await _remoteDatasource.createPost(
      title: title,
      content: content,
      image: image,
      onSendProgress: onSendProgress,
    );
    if (remoteResult is Right<Failure, PostModel>) {
      final model = remoteResult.value;
      await _localDatasource.upsert(model);
      return Right(model.toEntity());
    }
    final failure = (remoteResult as Left<Failure, PostModel>).value;
    if (failure is! NetworkFailure) {
      return Left(failure);
    }
    return _createOffline(title: title, content: content, image: image);
  }

  Future<Either<Failure, Post>> _createOffline({
    required String title,
    required String content,
    File? image,
  }) async {
    final author = _currentAuthor();
    final placeholderId = _nextLocalId();
    final placeholder = PostModel(
      id: placeholderId,
      authorId: author?.id ?? '',
      authorName: author?.displayName ?? '',
      authorPhotoUrl: author?.photoUrl,
      title: title,
      content: content,
      // No uploaded URL exists yet while offline; the real imageUrl only
      // arrives once the queued create is replayed and the server responds,
      // at which point the placeholder row is replaced entirely (see
      // buildPostPendingWriteReplayer).
      createdAt: DateTime.now(),
      commentsCount: 0,
      likesCount: 0,
    );

    await _queuePendingWrite(
      operation: PendingWriteOperation.create,
      payload: {
        'localId': placeholderId,
        'title': title,
        'content': content,
        'imagePath': image?.path,
      },
    );

    final upsertResult = await _localDatasource.upsert(placeholder);
    if (upsertResult is Left<Failure, void>) {
      return Left(upsertResult.value);
    }
    return Right(placeholder.toEntity());
  }

  @override
  Future<Either<Failure, Post>> updatePost(
    String id, {
    String? title,
    String? content,
  }) async {
    final remoteResult = await _remoteDatasource.updatePost(
      id,
      title: title,
      content: content,
    );
    if (remoteResult is Right<Failure, PostModel>) {
      final model = remoteResult.value;
      await _localDatasource.upsert(model);
      return Right(model.toEntity());
    }
    final failure = (remoteResult as Left<Failure, PostModel>).value;
    if (failure is! NetworkFailure) {
      return Left(failure);
    }
    return _updateOffline(id, title: title, content: content);
  }

  Future<Either<Failure, Post>> _updateOffline(
    String id, {
    String? title,
    String? content,
  }) async {
    final cacheResult = await _localDatasource.getById(id);
    if (cacheResult is Left<Failure, PostModel?>) {
      return Left(cacheResult.value);
    }
    final cached = (cacheResult as Right<Failure, PostModel?>).value;
    if (cached == null) {
      return Left(
        CacheFailure('Cannot update post $id offline: nothing cached for it.'),
      );
    }
    final updated = cached.copyWith(
      title: title ?? cached.title,
      content: content ?? cached.content,
      updatedAt: DateTime.now(),
    );

    await _queuePendingWrite(
      operation: PendingWriteOperation.update,
      payload: {'id': id, 'title': title, 'content': content},
    );

    final upsertResult = await _localDatasource.upsert(updated);
    if (upsertResult is Left<Failure, void>) {
      return Left(upsertResult.value);
    }
    return Right(updated.toEntity());
  }

  @override
  Future<Either<Failure, void>> deletePost(String id) async {
    final remoteResult = await _remoteDatasource.deletePost(id);
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
        entityType: postPendingWriteEntityType,
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
