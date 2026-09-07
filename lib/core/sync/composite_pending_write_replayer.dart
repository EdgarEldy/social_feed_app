import 'package:fpdart/fpdart.dart';

import '../database/pending_write.dart';
import '../errors/failure.dart';
import 'sync_service.dart';

/// A [PendingWriteReplayer] scoped to a single [PendingWrite.entityType],
/// paired with the [entityType] string it knows how to replay.
///
/// One feature builds one of these, e.g.
/// `buildPostPendingWriteReplayer` in
/// `features/posts/data/sync/post_pending_write_replayer.dart` for
/// `entityType == 'post'`. [CompositePendingWriteReplayer] then dispatches a
/// queued write to whichever entry declares the matching [entityType].
class EntityPendingWriteReplayer {
  const EntityPendingWriteReplayer({
    required this.entityType,
    required this.replay,
  });

  /// The [PendingWrite.entityType] this replayer handles, e.g. `'post'`.
  final String entityType;

  /// Replays a single queued write of that entity type against the real
  /// backend.
  final PendingWriteReplayer replay;
}

/// Dispatches a queued [PendingWrite] to whichever [EntityPendingWriteReplayer]
/// in [_replayers] declares the matching [PendingWrite.entityType].
///
/// [SyncService] only knows how to call a single [PendingWriteReplayer]
/// function; nothing in its own contract lets it try a second replayer if
/// the first does not recognize a row (see its class doc, it has no
/// built-in dispatch concept). `pending_writes` is still one shared table
/// across every feature that queues offline writes, though: `feature/posts`
/// writes `entityType: 'post'` rows today, and a later `feature/comments`
/// branch is expected to write `entityType: 'comment'` rows into the exact
/// same table. Rather than have `feature/posts`' own replayer special-case
/// every `entityType` it does not own (or, worse, crash/silently succeed on
/// one), this class is the small dispatcher that lets `SyncService` keep
/// working with one function while every feature only ever has to describe
/// its own entity type.
///
/// A later branch registering its own [EntityPendingWriteReplayer] means
/// appending one line to the list built in `injection_container.dart`;
/// neither this class nor `feature/posts`' replayer needs to change.
class CompositePendingWriteReplayer {
  CompositePendingWriteReplayer(this._replayers);

  final List<EntityPendingWriteReplayer> _replayers;

  /// The actual [PendingWriteReplayer] function to hand to [SyncService].
  Future<Either<Failure, void>> call(PendingWrite write) {
    for (final replayer in _replayers) {
      if (replayer.entityType == write.entityType) {
        return replayer.replay(write);
      }
    }
    // No feature has registered a replayer for this entityType. This
    // should not happen once every feature that writes to pending_writes
    // also registers a matching entry here, but returning a Left instead
    // of throwing keeps one unexpected row from crashing the whole drain
    // loop in SyncService._drainQueue; the row is simply left queued and
    // retried on the next reconnect, the same outcome a genuinely failed
    // replay gets.
    return Future.value(
      Left(
        CacheFailure(
          'No pending-write replayer registered for entityType '
          '"${write.entityType}".',
        ),
      ),
    );
  }
}
