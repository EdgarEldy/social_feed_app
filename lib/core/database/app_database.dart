import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens and owns the single `sqflite` [Database] instance used by every
/// local datasource in the app.
///
/// `sqflite` stores everything as flat rows, so this schema mirrors the
/// flat JSON shape of `PostModel`/`CommentModel` (see
/// `lib/features/posts/data/models/post_model.dart` and
/// `lib/features/comments/data/models/comment_model.dart`), plus a
/// `synced_at` column on each cache table recording when that row was last
/// written from a successful remote read. `pending_writes` queues mutations
/// made while offline for `SyncService` to replay once connectivity returns.
///
/// Registered as a lazy singleton in `get_it` the same way `Dio` and
/// `GoRouter` are: the constructor itself does nothing expensive, and the
/// actual file open only happens on the first call to [database], then is
/// cached for every call after. This keeps `configureDependencies()`
/// synchronous; callers `await` [database] instead of `get_it` awaiting an
/// async registration.
class AppDatabase {
  static const String fileName = 'socialfeed_app.db';

  /// Bumped whenever `_onCreate`/a future migration changes the schema.
  static const int databaseVersion = 1;

  static const String postsCacheTable = 'posts_cache';
  static const String commentsCacheTable = 'comments_cache';
  static const String pendingWritesTable = 'pending_writes';

  Database? _database;

  /// The open database, opening it lazily on first access.
  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final opened = await _open();
    _database = opened;
    return opened;
  }

  Future<Database> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, fileName);

    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $postsCacheTable (
            id TEXT PRIMARY KEY,
            author_id TEXT NOT NULL,
            author_name TEXT NOT NULL,
            author_photo_url TEXT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            image_url TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            comments_count INTEGER NOT NULL,
            likes_count INTEGER NOT NULL,
            is_liked_by_me INTEGER NOT NULL,
            synced_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $commentsCacheTable (
            id TEXT PRIMARY KEY,
            post_id TEXT NOT NULL,
            author_id TEXT NOT NULL,
            author_name TEXT NOT NULL,
            author_photo_url TEXT,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            synced_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $pendingWritesTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            operation TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Closes the underlying file handle, used by `get_it`'s dispose callback
  /// and by tests that want a clean database between runs.
  Future<void> close() async {
    final existing = _database;
    if (existing != null) {
      await existing.close();
      _database = null;
    }
  }
}
