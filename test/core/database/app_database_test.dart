import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:social_feed_app/core/database/app_database.dart';
import 'package:social_feed_app/core/database/local_datasource.dart';
import 'package:social_feed_app/features/posts/data/models/post_local_mapper.dart';
import 'package:social_feed_app/features/posts/data/models/post_model.dart';

/// Stand-in for the real platform plugin so [AppDatabase] can resolve an
/// application documents directory on the Dart VM, where no platform
/// channel is available. Points at a fresh temp directory per test run
/// instead of any real device path.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directoryPath);

  final String directoryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => directoryPath;
}

/// Minimal concrete [LocalDatasourceBase] built only for this test, the
/// same shape `PostLocalDatasource` (`feature/posts`) will later extend,
/// used here to exercise the real `posts_cache` schema created by
/// [AppDatabase] end to end.
class _TestPostLocalDatasource extends LocalDatasourceBase<PostModel> {
  _TestPostLocalDatasource(super.appDatabase)
      : super(tableName: AppDatabase.postsCacheTable);

  @override
  Map<String, Object?> toRow(PostModel entity) => entity.toRow();

  @override
  PostModel fromRow(Map<String, Object?> row) => PostLocalMapper.fromRow(row);
}

void main() {
  late Directory tempDirectory;
  late AppDatabase appDatabase;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('app_database_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    appDatabase = AppDatabase();
  });

  tearDown(() async {
    await appDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  final samplePost = PostModel(
    id: 'post-1',
    authorId: 'user-42',
    authorName: 'Ada Lovelace',
    authorPhotoUrl: 'https://example.com/avatars/ada.png',
    title: 'Hello world',
    content: 'My first post on the feed.',
    imageUrl: 'https://example.com/images/hello.png',
    createdAt: DateTime.utc(2026, 1, 15, 10, 30),
    updatedAt: DateTime.utc(2026, 1, 16, 8),
    commentsCount: 3,
    likesCount: 12,
    isLikedByMe: true,
  );

  group('AppDatabase schema', () {
    test('creates posts_cache, comments_cache and pending_writes tables on first open', () async {
      final db = await appDatabase.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tables.map((row) => row['name'] as String).toSet();

      expect(tableNames, containsAll(<String>[
        AppDatabase.postsCacheTable,
        AppDatabase.commentsCacheTable,
        AppDatabase.pendingWritesTable,
      ]));
    });

    test('caches the same Database instance across repeated calls', () async {
      final first = await appDatabase.database;
      final second = await appDatabase.database;

      expect(identical(first, second), isTrue);
    });
  });

  group('posts_cache insert/read round-trip', () {
    test('reads back an upserted post with every field intact', () async {
      final datasource = _TestPostLocalDatasource(appDatabase);

      final upsertResult = await datasource.upsert(samplePost);
      expect(upsertResult.isRight(), isTrue);

      final readResult = await datasource.getById(samplePost.id);

      expect(readResult.isRight(), isTrue);
      final roundTripped = readResult.toNullable();
      expect(roundTripped, isNotNull);
      expect(roundTripped!.id, samplePost.id);
      expect(roundTripped.authorId, samplePost.authorId);
      expect(roundTripped.authorName, samplePost.authorName);
      expect(roundTripped.authorPhotoUrl, samplePost.authorPhotoUrl);
      expect(roundTripped.title, samplePost.title);
      expect(roundTripped.content, samplePost.content);
      expect(roundTripped.imageUrl, samplePost.imageUrl);
      // sqflite stores DateTime as epoch millis, so the value read back is
      // always local time regardless of the original isUtc flag; compare
      // the moment in time rather than exact DateTime equality.
      expect(
        roundTripped.createdAt.isAtSameMomentAs(samplePost.createdAt),
        isTrue,
      );
      expect(
        roundTripped.updatedAt!.isAtSameMomentAs(samplePost.updatedAt!),
        isTrue,
      );
      expect(roundTripped.commentsCount, samplePost.commentsCount);
      expect(roundTripped.likesCount, samplePost.likesCount);
      expect(roundTripped.isLikedByMe, samplePost.isLikedByMe);
    });

    test('upsert replaces an existing row with the same id instead of duplicating it', () async {
      final datasource = _TestPostLocalDatasource(appDatabase);
      await datasource.upsert(samplePost);

      final updatedPost = samplePost.copyWith(title: 'Edited title');
      await datasource.upsert(updatedPost);

      final allResult = await datasource.getAll();
      final all = allResult.toNullable() ?? const <PostModel>[];
      expect(all, hasLength(1));
      expect(all.single.title, 'Edited title');
    });

    test('getById returns Right(null) when no row matches the id', () async {
      final datasource = _TestPostLocalDatasource(appDatabase);

      final result = await datasource.getById('does-not-exist');

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), isNull);
    });

    test('deleteById removes the row so it is no longer readable', () async {
      final datasource = _TestPostLocalDatasource(appDatabase);
      await datasource.upsert(samplePost);

      final deleteResult = await datasource.deleteById(samplePost.id);
      expect(deleteResult.isRight(), isTrue);

      final readResult = await datasource.getById(samplePost.id);
      expect(readResult.toNullable(), isNull);
    });

    test('round-trips null authorPhotoUrl, imageUrl and updatedAt as null', () async {
      final datasource = _TestPostLocalDatasource(appDatabase);
      final postWithNulls = samplePost.copyWith(
        authorPhotoUrl: null,
        imageUrl: null,
        updatedAt: null,
      );

      await datasource.upsert(postWithNulls);
      final readResult = await datasource.getById(postWithNulls.id);
      final roundTripped = readResult.toNullable();

      expect(roundTripped!.authorPhotoUrl, isNull);
      expect(roundTripped.imageUrl, isNull);
      expect(roundTripped.updatedAt, isNull);
    });
  });
}
