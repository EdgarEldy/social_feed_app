import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../errors/failure.dart';
import 'app_database.dart';

/// Generic local-cache half of the offline-first read strategy, reused by
/// `PostLocalDatasource` and `CommentLocalDatasource` (`feature/posts`,
/// `feature/comments`).
///
/// ## The offline-first read strategy
///
/// Every offline-first repository in this app (`PostRepositoryImpl`,
/// `CommentRepositoryImpl`, built in later branches) follows the same
/// three-step read pattern:
///
/// 1. **Try remote first.** Call the feature's `*RemoteDatasource`, which
///    wraps `dio` and maps any `DioException` to a `Failure` at the
///    datasource boundary (`core/network/dio_exception_mapper.dart`).
/// 2. **Fall back to the local cache on `NetworkFailure`.** If the remote
///    call fails specifically because there is no connectivity
///    (`NetworkFailure`, as opposed to a `ServerFailure`/
///    `UnauthorizedFailure`, which are real responses from the backend and
///    should be surfaced to the user as-is, not masked by stale cache
///    data), the repository reads from this local datasource instead of
///    failing outright.
/// 3. **Write-through on success.** Every successful remote read is
///    immediately upserted into the local cache (via [upsert]) before the
///    repository returns it, so step 2's fallback always has the freshest
///    data available the next time connectivity drops.
///
/// Concretely, a repository method built on top of this class looks
/// roughly like:
///
/// ```dart
/// Future<Either<Failure, List<Post>>> getPosts() async {
///   final remoteResult = await remoteDatasource.getPosts();
///   return remoteResult.match(
///     (failure) {
///       if (failure is NetworkFailure) {
///         return localDatasource.getAll();
///       }
///       return Left(failure);
///     },
///     (posts) async {
///       for (final post in posts) {
///         await localDatasource.upsert(post);
///       }
///       return Right(posts);
///     },
///   );
/// }
/// ```
///
/// [LocalDatasourceBase] only implements the local-cache half shown above:
/// generic insert-or-replace/read-all/read-one/delete CRUD against a single
/// `sqflite` table, parameterized by [tableName] and by the [toRow]/
/// [fromRow] mapping a subclass provides for its own model type. It has no
/// knowledge of any remote datasource or of the fallback decision itself;
/// that coordination belongs to each feature's own `*RepositoryImpl`, not
/// to this class.
///
/// A subclass plugs in a table and a model, reusing the mapper already
/// built alongside that model, e.g.:
///
/// ```dart
/// class PostLocalDatasource extends LocalDatasourceBase<PostModel> {
///   PostLocalDatasource(AppDatabase appDatabase)
///       : super(appDatabase, tableName: AppDatabase.postsCacheTable);
///
///   @override
///   Map<String, Object?> toRow(PostModel entity) => entity.toRow();
///
///   @override
///   PostModel fromRow(Map<String, Object?> row) =>
///       PostLocalMapper.fromRow(row);
/// }
/// ```
abstract class LocalDatasourceBase<T> {
  LocalDatasourceBase(this.appDatabase, {required this.tableName});

  /// Shared `sqflite` handle; see `core/database/app_database.dart`.
  final AppDatabase appDatabase;

  /// The table this instance reads and writes, e.g.
  /// [AppDatabase.postsCacheTable].
  final String tableName;

  /// Converts [entity] into the flat row shape `sqflite` expects. Left to
  /// the subclass so it can reuse the model's own `toRow()` mapper (see
  /// e.g. `PostModelLocalMapper` in
  /// `features/posts/data/models/post_local_mapper.dart`).
  Map<String, Object?> toRow(T entity);

  /// Converts a raw row back into a [T]. Left to the subclass for the same
  /// reason as [toRow].
  T fromRow(Map<String, Object?> row);

  /// Inserts [entity], replacing any existing row with the same primary
  /// key. Every cache table in this schema uses `id` as a `TEXT PRIMARY
  /// KEY`, so [toRow] is expected to include an `id` entry.
  Future<Either<Failure, void>> upsert(T entity) async {
    try {
      final db = await appDatabase.database;
      await db.insert(
        tableName,
        toRow(entity),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(CacheFailure('Failed to write to $tableName: $e'));
    }
  }

  /// Reads every row currently cached in [tableName].
  Future<Either<Failure, List<T>>> getAll() async {
    try {
      final db = await appDatabase.database;
      final rows = await db.query(tableName);
      return Right(rows.map(fromRow).toList());
    } on DatabaseException catch (e) {
      return Left(CacheFailure('Failed to read $tableName: $e'));
    }
  }

  /// Reads the single row with the given `id`, or `null` if there is no
  /// cached row for it.
  Future<Either<Failure, T?>> getById(String id) async {
    try {
      final db = await appDatabase.database;
      final rows = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Right(null);
      }
      return Right(fromRow(rows.first));
    } on DatabaseException catch (e) {
      return Left(CacheFailure('Failed to read $tableName: $e'));
    }
  }

  /// Deletes the row with the given `id`, a no-op if it is not cached.
  Future<Either<Failure, void>> deleteById(String id) async {
    try {
      final db = await appDatabase.database;
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(CacheFailure('Failed to delete from $tableName: $e'));
    }
  }
}
