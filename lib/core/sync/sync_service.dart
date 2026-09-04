import 'package:fpdart/fpdart.dart';
import 'package:mobx/mobx.dart';

import '../database/app_database.dart';
import '../database/pending_write.dart';
import '../errors/failure.dart';
import '../network_info/connectivity_store.dart';

/// Replays a single queued [PendingWrite] against the real backend and
/// reports whether it succeeded.
///
/// [SyncService] itself has no dependency on any specific feature's remote
/// datasource; it only knows how to read/delete rows in `pending_writes`
/// and how to react to connectivity changes. The actual "make the deferred
/// HTTP call" step is feature-specific (replaying a queued post creation
/// needs `PostRemoteDatasource.createPost`, a queued comment deletion needs
/// `CommentRemoteDatasource.deleteComment`, and so on), so it is injected
/// as this function type rather than hardcoded here.
///
/// `feature/posts` and `feature/comments` are expected to provide the real
/// implementation, most naturally by switching on [PendingWrite.entityType]
/// and [PendingWrite.operation] and delegating to the matching remote
/// datasource with the decoded `payloadJson`. Until one of those branches
/// wires a real replayer in, no [SyncService] is registered in `get_it`,
/// there is nothing meaningful yet for it to replay against.
typedef PendingWriteReplayer = Future<Either<Failure, void>> Function(
  PendingWrite write,
);

/// Replays mutations that were queued in `pending_writes` while the device
/// was offline, once connectivity comes back.
///
/// ## The offline-write strategy
///
/// A mutation made while offline (creating a post, deleting a comment, and
/// so on) is not silently dropped. The repository attempting it does two
/// things synchronously instead of failing outright:
///
/// 1. Writes a row describing the mutation into `pending_writes` (via
///    [AppDatabase]), carrying an `entity_type`, a JSON-encoded `payload`,
///    and the `operation` (create/update/delete). See [PendingWrite].
/// 2. Optimistically applies the same mutation to the local cache (e.g. a
///    `PostLocalDatasource.upsert` call), so the UI reflects the change
///    immediately even though the server has not confirmed it yet.
///
/// [SyncService] is the other half of that strategy: it watches
/// [ConnectivityStore.isOnline] and, the moment it flips from offline to
/// online, drains the queue in `created_at` order (oldest first), replaying
/// each row through the injected [PendingWriteReplayer]. A row is removed
/// from `pending_writes` only once its replay succeeds; a failed replay
/// leaves the row queued so the next reconnect (or the next manual
/// [syncNow] call) retries it, rather than losing the mutation.
///
/// [SyncService] is a plain Dart class, not a MobX `Store`: it reacts to
/// [ConnectivityStore] (which is a store) via [reaction] rather than the
/// `Observer` widget, since `Observer` needs a `BuildContext` and this
/// service does not run inside the widget tree.
class SyncService {
  SyncService({
    required this._appDatabase,
    required this._connectivityStore,
    required this._replayer,
  }) : _wasOnline = _connectivityStore.isOnline;

  final AppDatabase _appDatabase;
  final ConnectivityStore _connectivityStore;
  final PendingWriteReplayer _replayer;

  ReactionDisposer? _disposer;
  bool _wasOnline;
  Future<void>? _inFlightSync;

  /// Starts watching [ConnectivityStore.isOnline] for the offline-to-online
  /// transition. Call once, typically right after `get_it` resolves this
  /// service, mirroring how [ConnectivityStore] itself starts its stream
  /// subscription in its own constructor.
  void start() {
    _disposer = reaction<bool>(
      (_) => _connectivityStore.isOnline,
      (isOnline) {
        final justReconnected = isOnline && !_wasOnline;
        _wasOnline = isOnline;
        if (justReconnected) {
          syncNow();
        }
      },
    );
  }

  /// Stops watching connectivity changes. Call from `get_it`'s dispose
  /// callback so the reaction does not outlive the app, the same lifecycle
  /// [ConnectivityStore.dispose] follows.
  void dispose() {
    _disposer?.call();
  }

  /// Drains `pending_writes` in `created_at` order, replaying each row and
  /// removing it on success.
  ///
  /// Exposed as a public method, not just triggered internally by the
  /// connectivity [reaction], so a manual "retry sync" affordance in the UI
  /// (or a test) can trigger the same drain without faking a connectivity
  /// change. Concurrent calls share the same in-flight drain instead of
  /// racing two queries against `pending_writes` at once.
  Future<void> syncNow() {
    final existing = _inFlightSync;
    if (existing != null) {
      return existing;
    }

    final future = _drainQueue();
    _inFlightSync = future;
    return future.whenComplete(() => _inFlightSync = null);
  }

  Future<void> _drainQueue() async {
    final pending = await _readPendingWrites();
    for (final write in pending) {
      // The injected replayer is expected to return `Either<Failure, void>`,
      // but it is feature-supplied code (see the typedef doc above) and may
      // throw instead of returning a `Left` if something unexpected goes
      // wrong deep inside it. Treating that thrown exception the same as a
      // failed replay, rather than letting it escape the loop, keeps one bad
      // write from aborting the rest of the batch.
      bool succeeded;
      try {
        final result = await _replayer(write);
        succeeded = result.isRight();
      } catch (_) {
        succeeded = false;
      }
      if (succeeded) {
        await _remove(write);
      }
      // A failed replay is deliberately left in `pending_writes`; the next
      // reconnect, or the next manual syncNow() call, retries it.
    }
  }

  Future<List<PendingWrite>> _readPendingWrites() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.pendingWritesTable,
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingWrite.fromRow).toList();
  }

  Future<void> _remove(PendingWrite write) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.pendingWritesTable,
      where: 'id = ?',
      whereArgs: [write.id],
    );
  }
}
