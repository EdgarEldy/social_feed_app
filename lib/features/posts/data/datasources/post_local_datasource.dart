import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_datasource.dart';
import '../models/post_local_mapper.dart';
import '../models/post_model.dart';

/// The `sqflite` half of the offline-first strategy for posts: CRUD against
/// the `posts_cache` table.
///
/// This is the first real usage of [LocalDatasourceBase], the generic
/// reference pattern it was built for in `feature/offline-and-sync`; it does
/// nothing beyond plugging in [AppDatabase.postsCacheTable] and the
/// [PostModel] mapping already built alongside the model
/// (`PostModelLocalMapper`/`PostLocalMapper` in
/// `data/models/post_local_mapper.dart`). `PostRepositoryImpl` is the class
/// that actually decides when to read from here versus the network.
class PostLocalDatasource extends LocalDatasourceBase<PostModel> {
  PostLocalDatasource(super.appDatabase)
      : super(tableName: AppDatabase.postsCacheTable);

  @override
  Map<String, Object?> toRow(PostModel entity) => entity.toRow();

  @override
  PostModel fromRow(Map<String, Object?> row) => PostLocalMapper.fromRow(row);
}
