/// The kind of mutation a queued [PendingWrite] represents.
///
/// Mirrors the CRUD-style operations every feature repository performs
/// against the API: creating a resource, updating one, or deleting one.
/// Stored in the `operation` column of `pending_writes` as its [name] (see
/// `core/database/app_database.dart`), so adding a new value here is a
/// backwards-compatible schema change, no migration needed.
enum PendingWriteOperation { create, update, delete }

/// A single queued mutation, made while the device was offline, waiting to
/// be replayed against the backend once connectivity returns.
///
/// This is the in-memory counterpart of a row in the `pending_writes`
/// table. A repository writes one of these (via [toRow]) at the same time
/// it optimistically applies the mutation to the local cache; `SyncService`
/// (`core/sync/sync_service.dart`) later reads them back (via [fromRow]) to
/// replay them in order.
///
/// [entityType] is a plain string rather than an enum on purpose: this
/// class lives in `core/` and has no knowledge of which features exist.
/// Each feature is free to pick its own constant (e.g. `'post'`,
/// `'comment'`) as long as its `PendingWriteReplayer` recognizes the same
/// value it writes.
///
/// [payloadJson] is the JSON-encoded body of the mutation, typically
/// whatever the matching `*Model.toJson()` produces, so the replayer can
/// decode it back into the shape the remote datasource expects without
/// `core/` needing to know that shape either.
class PendingWrite {
  const PendingWrite({
    this.id,
    required this.entityType,
    required this.payloadJson,
    required this.operation,
    required this.createdAt,
  });

  /// The `pending_writes.id` primary key. `null` for a row not yet
  /// inserted, since the column is `INTEGER PRIMARY KEY AUTOINCREMENT` and
  /// `sqflite` assigns it on insert.
  final int? id;

  final String entityType;
  final String payloadJson;
  final PendingWriteOperation operation;
  final DateTime createdAt;

  /// Builds the row `sqflite` expects for an insert into `pending_writes`.
  /// [id] is intentionally omitted when `null` so the autoincrement column
  /// assigns it rather than inserting an explicit `NULL`.
  Map<String, Object?> toRow() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'payload_json': payloadJson,
      'operation': operation.name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static PendingWrite fromRow(Map<String, Object?> row) {
    return PendingWrite(
      id: row['id'] as int?,
      entityType: row['entity_type'] as String,
      payloadJson: row['payload_json'] as String,
      operation: PendingWriteOperation.values.byName(
        row['operation'] as String,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      ),
    );
  }
}
