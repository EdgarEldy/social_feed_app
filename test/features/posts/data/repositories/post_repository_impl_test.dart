import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:social_feed_app/core/database/app_database.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/features/posts/data/datasources/post_local_datasource.dart';
import 'package:social_feed_app/features/posts/data/datasources/post_remote_datasource.dart';
import 'package:social_feed_app/features/posts/data/models/post_model.dart';
import 'package:social_feed_app/features/posts/data/repositories/post_repository_impl.dart';

/// Stands in for the real platform plugin so [AppDatabase] can resolve an
/// application documents directory on the Dart VM, exactly like
/// `test/core/database/app_database_test.dart` does. Points at a fresh temp
/// directory per test, never a real device path.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directoryPath);

  final String directoryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => directoryPath;
}

class _MockPostRemoteDatasource extends Mock implements PostRemoteDatasource {}

class _MockPostLocalDatasource extends Mock implements PostLocalDatasource {}

PostModel _buildPostModel({
  required String id,
  required DateTime createdAt,
  String authorId = 'author-1',
  String authorName = 'Ada Lovelace',
  String title = 'A post',
  String content = 'Some content',
}) {
  return PostModel(
    id: id,
    authorId: authorId,
    authorName: authorName,
    title: title,
    content: content,
    createdAt: createdAt,
    commentsCount: 0,
    likesCount: 0,
  );
}

void main() {
  late Directory tempDirectory;
  late AppDatabase appDatabase;
  late _MockPostRemoteDatasource remoteDatasource;
  late _MockPostLocalDatasource localDatasource;
  late PostRepositoryImpl repository;

  const currentAuthor = (
    id: 'author-1',
    displayName: 'Ada Lovelace',
    photoUrl: null,
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(
      _buildPostModel(id: 'fallback', createdAt: DateTime(2026, 1, 1)),
    );
  });

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'post_repository_impl_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    appDatabase = AppDatabase();
    remoteDatasource = _MockPostRemoteDatasource();
    localDatasource = _MockPostLocalDatasource();
    repository = PostRepositoryImpl(
      remoteDatasource: remoteDatasource,
      localDatasource: localDatasource,
      appDatabase: appDatabase,
      currentAuthor: () => currentAuthor,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  Future<List<Map<String, Object?>>> readPendingWrites() async {
    final db = await appDatabase.database;
    return db.query(AppDatabase.pendingWritesTable);
  }

  group('getPosts cache fallback', () {
    test('returns cached posts newest-first on a NetworkFailure from the remote', () async {
      final older = _buildPostModel(id: 'post-old', createdAt: DateTime(2026, 1, 1));
      final newer = _buildPostModel(id: 'post-new', createdAt: DateTime(2026, 2, 1));

      when(
        () => remoteDatasource.getPosts(cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.getAll(),
      ).thenAnswer((_) async => Right([older, newer]));

      final result = await repository.getPosts();

      expect(result.isRight(), isTrue);
      final page = result.getOrElse((_) => const PaginatedResult(items: []));
      expect(page.items.map((p) => p.id).toList(), ['post-new', 'post-old']);
      expect(page.nextCursor, isNull);
    });
  });

  group('createPost offline write', () {
    test('returns Right and queues a pending write even when the local cache upsert fails', () async {
      when(
        () => remoteDatasource.createPost(
          title: 'Title',
          content: 'Content',
          image: null,
          onSendProgress: null,
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.createPost(
        title: 'Title',
        content: 'Content',
      );

      expect(result.isRight(), isTrue);
      final post = result.getOrElse((_) => throw StateError('expected Right'));
      expect(post.title, 'Title');
      expect(post.id, startsWith('local-'));

      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, hasLength(1));
      expect(pendingWrites.single['entity_type'], 'post');
      expect(pendingWrites.single['operation'], 'create');
    });
  });

  group('updatePost offline write', () {
    test('returns Right and queues a pending write even when the local cache upsert fails', () async {
      final cached = _buildPostModel(id: 'post-1', createdAt: DateTime(2026, 1, 1));

      when(
        () => remoteDatasource.updatePost('post-1', title: 'New title', content: null),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.getById('post-1'),
      ).thenAnswer((_) async => Right(cached));
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.updatePost('post-1', title: 'New title');

      expect(result.isRight(), isTrue);
      final post = result.getOrElse((_) => throw StateError('expected Right'));
      expect(post.title, 'New title');

      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, hasLength(1));
      expect(pendingWrites.single['entity_type'], 'post');
      expect(pendingWrites.single['operation'], 'update');
    });

    test('returns a CacheFailure when nothing is cached for the post to update offline', () async {
      when(
        () => remoteDatasource.updatePost('post-1', title: 'New title', content: null),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.getById('post-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.updatePost('post-1', title: 'New title');

      expect(result.isLeft(), isTrue);
      expect(
        result.match((failure) => failure, (_) => null),
        isA<CacheFailure>(),
      );
      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, isEmpty);
    });
  });

  group('deletePost offline write', () {
    test('returns Right and queues a pending write even when the local cache delete fails', () async {
      when(
        () => remoteDatasource.deletePost('post-1'),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.deleteById(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.deletePost('post-1');

      expect(result, const Right<Failure, void>(null));

      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, hasLength(1));
      expect(pendingWrites.single['entity_type'], 'post');
      expect(pendingWrites.single['operation'], 'delete');
    });

    test('surfaces a ServerFailure as-is without queuing a pending write', () async {
      when(
        () => remoteDatasource.deletePost('post-1'),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Not found.', statusCode: 404)),
      );

      final result = await repository.deletePost('post-1');

      expect(
        result,
        const Left<Failure, void>(ServerFailure('Not found.', statusCode: 404)),
      );
      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, isEmpty);
    });
  });
}
