import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:social_feed_app/core/database/app_database.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/features/comments/data/datasources/comment_local_datasource.dart';
import 'package:social_feed_app/features/comments/data/datasources/comment_remote_datasource.dart';
import 'package:social_feed_app/features/comments/data/models/comment_model.dart';
import 'package:social_feed_app/features/comments/data/repositories/comment_repository_impl.dart';

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

class _MockCommentRemoteDatasource extends Mock
    implements CommentRemoteDatasource {}

class _MockCommentLocalDatasource extends Mock
    implements CommentLocalDatasource {}

CommentModel _buildCommentModel({
  required String id,
  required String postId,
  required DateTime createdAt,
  String authorId = 'author-1',
  String authorName = 'Ada Lovelace',
  String content = 'A comment',
}) {
  return CommentModel(
    id: id,
    postId: postId,
    authorId: authorId,
    authorName: authorName,
    content: content,
    createdAt: createdAt,
  );
}

void main() {
  late Directory tempDirectory;
  late AppDatabase appDatabase;
  late _MockCommentRemoteDatasource remoteDatasource;
  late _MockCommentLocalDatasource localDatasource;
  late CommentRepositoryImpl repository;

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
      _buildCommentModel(
        id: 'fallback',
        postId: 'fallback-post',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'comment_repository_impl_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    appDatabase = AppDatabase();
    remoteDatasource = _MockCommentRemoteDatasource();
    localDatasource = _MockCommentLocalDatasource();
    repository = CommentRepositoryImpl(
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

  group('getComments cache fallback', () {
    test('returns cached comments oldest-first on a NetworkFailure from the remote', () async {
      final older = _buildCommentModel(
        id: 'comment-old',
        postId: 'post-1',
        createdAt: DateTime(2026, 1, 1),
        content: 'First comment',
      );
      final newer = _buildCommentModel(
        id: 'comment-new',
        postId: 'post-1',
        createdAt: DateTime(2026, 2, 1),
        content: 'Second comment',
      );

      when(
        () => remoteDatasource.getComments('post-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.getByPostId('post-1'),
      ).thenAnswer((_) async => Right([newer, older]));

      final result = await repository.getComments('post-1');

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(
        (_) => const PaginatedResult(items: []),
      );
      expect(page.items.map((c) => c.id).toList(), ['comment-old', 'comment-new']);
      expect(page.nextCursor, isNull);
    });

    test('surfaces a ServerFailure as-is without falling back to the cache', () async {
      when(
        () => remoteDatasource.getComments('post-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Post not found.', statusCode: 404)),
      );

      final result = await repository.getComments('post-1');

      expect(
        result,
        const Left<Failure, PaginatedResult<Object>>(
          ServerFailure('Post not found.', statusCode: 404),
        ),
      );
      verifyNever(() => localDatasource.getByPostId(any()));
    });

    test('propagates a CacheFailure when the fallback cache read itself fails', () async {
      when(
        () => remoteDatasource.getComments('post-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(() => localDatasource.getByPostId('post-1')).thenAnswer(
        (_) async => const Left(CacheFailure('Failed to read comments_cache.')),
      );

      final result = await repository.getComments('post-1');

      expect(
        result,
        const Left<Failure, PaginatedResult<Object>>(
          CacheFailure('Failed to read comments_cache.'),
        ),
      );
    });

    test('writes every remote comment through to the cache on success', () async {
      final remoteComment = _buildCommentModel(
        id: 'comment-1',
        postId: 'post-1',
        createdAt: DateTime(2026, 1, 1),
      );
      when(
        () => remoteDatasource.getComments('post-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResult(items: [remoteComment], nextCursor: 'cursor-2'),
        ),
      );
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.getComments('post-1');

      expect(result.isRight(), isTrue);
      verify(() => localDatasource.upsert(remoteComment)).called(1);
    });
  });

  group('addComment offline write', () {
    test('returns Right and queues a pending write even when the local cache upsert fails', () async {
      when(
        () => remoteDatasource.addComment(postId: 'post-1', content: 'Hello'),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.addComment(
        postId: 'post-1',
        content: 'Hello',
      );

      expect(result.isRight(), isTrue);
      final comment = result.getOrElse((_) => throw StateError('expected Right'));
      expect(comment.content, 'Hello');
      expect(comment.postId, 'post-1');
      expect(comment.id, startsWith('local-'));

      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, hasLength(1));
      expect(pendingWrites.single['entity_type'], 'comment');
      expect(pendingWrites.single['operation'], 'create');
    });

    test('returns Right when the offline cache upsert also succeeds', () async {
      when(
        () => remoteDatasource.addComment(postId: 'post-1', content: 'Hello'),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.addComment(
        postId: 'post-1',
        content: 'Hello',
      );

      expect(result.isRight(), isTrue);
      verify(() => localDatasource.upsert(any())).called(1);
    });

    test('surfaces a ServerFailure as-is without queuing a pending write', () async {
      when(
        () => remoteDatasource.addComment(postId: 'post-1', content: 'Hello'),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Bad request.', statusCode: 400)),
      );

      final result = await repository.addComment(
        postId: 'post-1',
        content: 'Hello',
      );

      expect(
        result,
        const Left<Failure, Object>(ServerFailure('Bad request.', statusCode: 400)),
      );
      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, isEmpty);
    });
  });

  group('deleteComment offline write', () {
    test('returns Right and queues a pending write even when the local cache delete fails', () async {
      when(
        () => remoteDatasource.deleteComment('comment-1'),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.deleteById(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.deleteComment('comment-1');

      expect(result, const Right<Failure, void>(null));

      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, hasLength(1));
      expect(pendingWrites.single['entity_type'], 'comment');
      expect(pendingWrites.single['operation'], 'delete');
    });

    test('returns Right when the remote delete succeeds and removes the cached row', () async {
      when(
        () => remoteDatasource.deleteComment('comment-1'),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => localDatasource.deleteById('comment-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.deleteComment('comment-1');

      expect(result, const Right<Failure, void>(null));
      verify(() => localDatasource.deleteById('comment-1')).called(1);
      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, isEmpty);
    });

    test('surfaces a ServerFailure as-is without queuing a pending write', () async {
      when(
        () => remoteDatasource.deleteComment('comment-1'),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Not found.', statusCode: 404)),
      );

      final result = await repository.deleteComment('comment-1');

      expect(
        result,
        const Left<Failure, void>(ServerFailure('Not found.', statusCode: 404)),
      );
      final pendingWrites = await readPendingWrites();
      expect(pendingWrites, isEmpty);
    });
  });
}
