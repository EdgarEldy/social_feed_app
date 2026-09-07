import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_posts_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/update_post_usecase.dart';
import 'package:social_feed_app/features/posts/presentation/stores/posts_store.dart';

class _MockGetPostsUseCase extends Mock implements GetPostsUseCase {}

class _MockGetPostUseCase extends Mock implements GetPostUseCase {}

class _MockCreatePostUseCase extends Mock implements CreatePostUseCase {}

class _MockDeletePostUseCase extends Mock implements DeletePostUseCase {}

class _MockUpdatePostUseCase extends Mock implements UpdatePostUseCase {}

void main() {
  late _MockGetPostsUseCase getPostsUseCase;
  late _MockGetPostUseCase getPostUseCase;
  late _MockCreatePostUseCase createPostUseCase;
  late _MockDeletePostUseCase deletePostUseCase;
  late _MockUpdatePostUseCase updatePostUseCase;
  late PostsStore store;

  Post buildPost({required String id, String title = 'Title', String content = 'Content'}) {
    return Post(
      id: id,
      authorId: 'user-1',
      authorName: 'Ada Lovelace',
      title: title,
      content: content,
      createdAt: DateTime(2026, 1, 1),
      commentsCount: 0,
      likesCount: 0,
      isLikedByMe: false,
    );
  }

  setUp(() {
    getPostsUseCase = _MockGetPostsUseCase();
    getPostUseCase = _MockGetPostUseCase();
    createPostUseCase = _MockCreatePostUseCase();
    deletePostUseCase = _MockDeletePostUseCase();
    updatePostUseCase = _MockUpdatePostUseCase();

    store = PostsStore(
      getPostsUseCase: getPostsUseCase,
      getPostUseCase: getPostUseCase,
      createPostUseCase: createPostUseCase,
      deletePostUseCase: deletePostUseCase,
      updatePostUseCase: updatePostUseCase,
    );
  });

  group('PostsStore loadPosts', () {
    test('replaces posts and stores the next cursor on success', () async {
      final page = PaginatedResult<Post>(
        items: [buildPost(id: 'post-1'), buildPost(id: 'post-2')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));

      await store.loadPosts();

      expect(store.posts.map((post) => post.id), ['post-1', 'post-2']);
      expect(store.feedError, isNull);
      expect(store.isLoadingFeed, isFalse);
      expect(store.hasLoadedOnce, isTrue);
    });

    test('sets feedError and leaves posts empty on failure', () async {
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)));

      await store.loadPosts();

      expect(store.posts, isEmpty);
      expect(store.feedError, const ServerFailure('Unexpected server error.', statusCode: 500));
      expect(store.hasLoadedOnce, isTrue);
    });
  });

  group('PostsStore loadMore', () {
    test('appends new posts and advances the cursor', () async {
      final firstPage = PaginatedResult<Post>(
        items: [buildPost(id: 'post-1'), buildPost(id: 'post-2')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(firstPage));
      await store.loadPosts();

      final secondPage = PaginatedResult<Post>(
        items: [buildPost(id: 'post-3')],
        nextCursor: null,
      );
      when(
        () => getPostsUseCase.call(cursor: 'cursor-2', limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(secondPage));

      await store.loadMore();

      expect(store.posts.map((post) => post.id), ['post-1', 'post-2', 'post-3']);
    });

    test('does not duplicate posts already present when the next page overlaps with what is loaded', () async {
      final firstPage = PaginatedResult<Post>(
        items: [buildPost(id: 'post-1'), buildPost(id: 'post-2')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(firstPage));
      await store.loadPosts();

      // Simulates the offline-cache fallback in GetPostsUseCase/
      // PostRepositoryImpl, which returns the entire cached set rather than
      // a real next page: post-1 and post-2 are already loaded, and this
      // "next page" repeats them alongside one genuinely new post.
      final cacheFallbackPage = PaginatedResult<Post>(
        items: [buildPost(id: 'post-1'), buildPost(id: 'post-2'), buildPost(id: 'post-3')],
        nextCursor: null,
      );
      when(
        () => getPostsUseCase.call(cursor: 'cursor-2', limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(cacheFallbackPage));

      await store.loadMore();

      final ids = store.posts.map((post) => post.id).toList();
      expect(ids, ['post-1', 'post-2', 'post-3']);
      expect(ids.toSet().length, ids.length);
    });

    test('is a no-op once there is no next cursor', () async {
      final page = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: null);
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      await store.loadMore();

      verify(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).called(1);
      expect(store.posts.map((post) => post.id), ['post-1']);
    });

    test('sets feedError and leaves posts unchanged on failure', () async {
      final firstPage = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: 'cursor-2');
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(firstPage));
      await store.loadPosts();

      when(
        () => getPostsUseCase.call(cursor: 'cursor-2', limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Left(NetworkFailure('No internet connection.')));

      await store.loadMore();

      expect(store.feedError, const NetworkFailure('No internet connection.'));
      expect(store.posts.map((post) => post.id), ['post-1']);
    });
  });

  group('PostsStore loadPost', () {
    test('sets currentPost on success', () async {
      final post = buildPost(id: 'post-1');
      when(() => getPostUseCase.call('post-1')).thenAnswer((_) async => Right(post));

      await store.loadPost('post-1');

      expect(store.currentPost, post);
      expect(store.currentPostError, isNull);
      expect(store.isLoadingCurrentPost, isFalse);
    });

    test('sets currentPostError and leaves currentPost null on failure', () async {
      when(
        () => getPostUseCase.call('post-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('Post not found.', statusCode: 404)));

      await store.loadPost('post-1');

      expect(store.currentPost, isNull);
      expect(store.currentPostError, const ServerFailure('Post not found.', statusCode: 404));
    });
  });

  group('PostsStore deletePost', () {
    test('removes the post from posts on success', () async {
      final page = PaginatedResult<Post>(
        items: [buildPost(id: 'post-1'), buildPost(id: 'post-2')],
        nextCursor: null,
      );
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      when(() => deletePostUseCase.call('post-1')).thenAnswer((_) async => const Right(null));

      await store.deletePost('post-1');

      expect(store.posts.map((post) => post.id), ['post-2']);
      expect(store.deleteError, isNull);
      expect(store.deletingPostId, isNull);
    });

    test('sets deleteError and leaves posts unchanged on failure', () async {
      final page = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: null);
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      when(
        () => deletePostUseCase.call('post-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)));

      await store.deletePost('post-1');

      expect(store.posts.map((post) => post.id), ['post-1']);
      expect(store.deleteError, const ServerFailure('Unexpected server error.', statusCode: 500));
      expect(store.deletingPostId, isNull);
    });
  });

  group('PostsStore updatePost', () {
    test('reconciles both posts and currentPost with the updated post on success', () async {
      final page = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: null);
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      when(() => getPostUseCase.call('post-1')).thenAnswer((_) async => Right(buildPost(id: 'post-1')));
      await store.loadPost('post-1');

      final updated = buildPost(id: 'post-1', title: 'Updated title');
      when(
        () => updatePostUseCase.call('post-1', title: 'Updated title', content: any(named: 'content')),
      ).thenAnswer((_) async => Right(updated));

      await store.updatePost('post-1', title: 'Updated title');

      expect(store.posts.first.title, 'Updated title');
      expect(store.currentPost?.title, 'Updated title');
      expect(store.updateError, isNull);
      expect(store.updatingPostId, isNull);
    });

    test('sets updateError and leaves posts/currentPost unchanged on failure', () async {
      final page = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: null);
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      when(
        () => updatePostUseCase.call(
          'post-1',
          title: any(named: 'title'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)));

      await store.updatePost('post-1', title: 'New title');

      expect(store.posts.first.title, 'Title');
      expect(store.updateError, const ServerFailure('Unexpected server error.', statusCode: 500));
      expect(store.updatingPostId, isNull);
    });
  });

  group('PostsStore createPost', () {
    test('prepends the created post to posts on success', () async {
      final page = PaginatedResult<Post>(items: [buildPost(id: 'post-1')], nextCursor: null);
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(page));
      await store.loadPosts();

      final created = buildPost(id: 'post-2');
      when(
        () => createPostUseCase.call(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((_) async => Right(created));

      final result = await store.createPost(
        title: 'Title for post-2',
        content: 'Content for post-2',
        onSendProgress: (sent, total) {},
      );

      expect(result, Right<Failure, Post>(created));
      expect(store.posts.map((post) => post.id), ['post-2', 'post-1']);
      expect(store.creatingPost, isFalse);
      expect(store.createError, isNull);
    });

    test('sets createError and leaves posts unchanged on failure', () async {
      when(
        () => createPostUseCase.call(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((_) async => const Left(ValidationFailure('Title cannot be empty.')));

      final result = await store.createPost(
        title: '',
        content: 'Content',
        onSendProgress: (sent, total) {},
      );

      expect(result, const Left<Failure, Post>(ValidationFailure('Title cannot be empty.')));
      expect(store.posts, isEmpty);
      expect(store.createError, const ValidationFailure('Title cannot be empty.'));
      expect(store.creatingPost, isFalse);
    });
  });
}
