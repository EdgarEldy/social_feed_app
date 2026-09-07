import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_datasource.dart';
import '../../../../core/errors/failure.dart';
import '../models/comment_local_mapper.dart';
import '../models/comment_model.dart';

/// The `sqflite` half of the offline-first strategy for comments: CRUD
/// against the `comments_cache` table.
///
/// Mirrors `PostLocalDatasource` exactly: it plugs [LocalDatasourceBase]
/// into [AppDatabase.commentsCacheTable] and the [CommentModel] mapping
/// already built alongside the model
/// (`CommentModelLocalMapper`/`CommentLocalMapper` in
/// `data/models/comment_local_mapper.dart`). `CommentRepositoryImpl` is the
/// class that actually decides when to read from here versus the network.
///
/// Unlike `posts_cache`, `comments_cache` holds rows for every post at
/// once, so this class adds [getByPostId] on top of the inherited CRUD:
/// `LocalDatasourceBase.getAll` reads the whole table, which is correct for
/// `posts_cache` (a single feed) but would leak comments from unrelated
/// posts into a single post's offline fallback here.
class CommentLocalDatasource extends LocalDatasourceBase<CommentModel> {
  CommentLocalDatasource(super.appDatabase)
      : super(tableName: AppDatabase.commentsCacheTable);

  @override
  Map<String, Object?> toRow(CommentModel entity) => entity.toRow();

  @override
  CommentModel fromRow(Map<String, Object?> row) =>
      CommentLocalMapper.fromRow(row);

  /// Reads every cached comment belonging to [postId].
  ///
  /// Follows the same try/catch shape as every method on
  /// [LocalDatasourceBase]: a [DatabaseException] or any other [Exception]
  /// raised while opening/querying the database is mapped to a
  /// [CacheFailure] here rather than escaping the data layer.
  Future<Either<Failure, List<CommentModel>>> getByPostId(
    String postId,
  ) async {
    try {
      final db = await appDatabase.database;
      final rows = await db.query(
        tableName,
        where: 'post_id = ?',
        whereArgs: [postId],
      );
      return Right(rows.map(fromRow).toList());
    } on DatabaseException catch (e) {
      return Left(CacheFailure('Failed to read $tableName: $e'));
    } on Exception catch (e) {
      return Left(CacheFailure('Failed to read $tableName: $e'));
    }
  }
}
