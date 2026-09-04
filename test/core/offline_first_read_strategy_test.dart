import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/database/local_datasource.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/posts/data/models/post_model.dart';

/// Stands in for the `PostRemoteDatasource` `feature/posts` will build:
/// a thin wrapper around `dio` returning `Either<Failure, List<PostModel>>`
/// once any `DioException` has already been mapped to a [Failure]. Declared
/// locally to this test file because the real datasource does not exist
/// yet on this branch.
abstract class _PostRemoteDatasource {
  Future<Either<Failure, List<PostModel>>> getPosts();
}

class _MockPostRemoteDatasource extends Mock implements _PostRemoteDatasource {}

/// The real base class from `core/database/local_datasource.dart`, mocked
/// rather than backed by a concrete subclass, since the point of this test
/// is the *coordination* logic in [_OfflineFirstPostRepository], not
/// `LocalDatasourceBase`'s own `sqflite` behavior (already covered by
/// `test/core/database/app_database_test.dart`).
class _MockPostLocalDatasource extends Mock implements LocalDatasourceBase<PostModel> {}

/// Minimal test-local stand-in for the `PostRepositoryImpl` that
/// `feature/posts` will build. No concrete `*RepositoryImpl` exists in
/// `lib/` on this branch, so this reproduces just enough of the offline-
/// first read strategy documented on [LocalDatasourceBase] (try remote,
/// fall back to the cache on `NetworkFailure`, write-through on success)
/// to prove the pattern is actually testable and behaves as documented,
/// wired against a mocked remote and a mocked local datasource exactly as
/// `feature/posts`'s real `getPosts()` will be.
class _OfflineFirstPostRepository {
  _OfflineFirstPostRepository({
    required this._remoteDatasource,
    required this._localDatasource,
  });

  final _PostRemoteDatasource _remoteDatasource;
  final LocalDatasourceBase<PostModel> _localDatasource;

  Future<Either<Failure, List<PostModel>>> getPosts() async {
    final remoteResult = await _remoteDatasource.getPosts();
    return remoteResult.match(
      (failure) async {
        if (failure is NetworkFailure) {
          return _localDatasource.getAll();
        }
        return Left(failure);
      },
      (posts) async {
        for (final post in posts) {
          await _localDatasource.upsert(post);
        }
        return Right(posts);
      },
    );
  }
}

void main() {
  late _MockPostRemoteDatasource remoteDatasource;
  late _MockPostLocalDatasource localDatasource;
  late _OfflineFirstPostRepository repository;

  setUpAll(() {
    registerFallbackValue(
      PostModel(
        id: 'fallback',
        authorId: 'fallback-author',
        authorName: 'Fallback Author',
        title: 'fallback',
        content: 'fallback',
        createdAt: DateTime(2026, 1, 1),
        commentsCount: 0,
        likesCount: 0,
      ),
    );
  });

  setUp(() {
    remoteDatasource = _MockPostRemoteDatasource();
    localDatasource = _MockPostLocalDatasource();
    repository = _OfflineFirstPostRepository(
      remoteDatasource: remoteDatasource,
      localDatasource: localDatasource,
    );
  });

  final remotePost = PostModel(
    id: 'post-remote',
    authorId: 'user-1',
    authorName: 'Ada Lovelace',
    title: 'Fresh from the server',
    content: 'Straight off GET /posts.',
    createdAt: DateTime(2026, 2, 1),
    commentsCount: 0,
    likesCount: 0,
  );

  final cachedPost = PostModel(
    id: 'post-cached',
    authorId: 'user-2',
    authorName: 'Grace Hopper',
    title: 'Read from the cache',
    content: 'Served while offline.',
    createdAt: DateTime(2026, 1, 20),
    commentsCount: 0,
    likesCount: 0,
  );

  group('getPosts (offline-first read strategy)', () {
    test('returns the remote posts and writes each one through to the local cache on success', () async {
      when(
        () => remoteDatasource.getPosts(),
      ).thenAnswer((_) async => Right([remotePost]));
      when(
        () => localDatasource.upsert(any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.getPosts();

      // Either.== delegates straight to the wrapped value's ==, and Dart's
      // List does not override == (identity only), so comparing two
      // separately-built Right(<List>) instances would never be equal even
      // with identical contents. Unwrapping and comparing the list itself
      // goes through the list-aware `equals` matcher instead.
      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => const []), [remotePost]);
      verify(() => localDatasource.upsert(remotePost)).called(1);
      verifyNever(() => localDatasource.getAll());
    });

    test('falls back to the local cache when the remote call fails with NetworkFailure', () async {
      when(() => remoteDatasource.getPosts()).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(
        () => localDatasource.getAll(),
      ).thenAnswer((_) async => Right([cachedPost]));

      final result = await repository.getPosts();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => const []), [cachedPost]);
      verify(() => localDatasource.getAll()).called(1);
      verifyNever(() => localDatasource.upsert(any()));
    });

    test('surfaces a ServerFailure as-is without touching the cache', () async {
      when(() => remoteDatasource.getPosts()).thenAnswer(
        (_) async => const Left(ServerFailure('Internal error.', statusCode: 500)),
      );

      final result = await repository.getPosts();

      expect(
        result,
        const Left<Failure, List<PostModel>>(
          ServerFailure('Internal error.', statusCode: 500),
        ),
      );
      verifyNever(() => localDatasource.getAll());
      verifyNever(() => localDatasource.upsert(any()));
    });

    test('surfaces an UnauthorizedFailure as-is without falling back to the cache', () async {
      when(() => remoteDatasource.getPosts()).thenAnswer(
        (_) async => const Left(UnauthorizedFailure('Session expired.')),
      );

      final result = await repository.getPosts();

      expect(
        result,
        const Left<Failure, List<PostModel>>(UnauthorizedFailure('Session expired.')),
      );
      verifyNever(() => localDatasource.getAll());
    });

    test('propagates a CacheFailure when the fallback cache read itself fails', () async {
      when(() => remoteDatasource.getPosts()).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );
      when(() => localDatasource.getAll()).thenAnswer(
        (_) async => const Left(CacheFailure('Failed to read posts_cache.')),
      );

      final result = await repository.getPosts();

      expect(
        result,
        const Left<Failure, List<PostModel>>(CacheFailure('Failed to read posts_cache.')),
      );
    });
  });
}
