import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/features/comments/domain/entities/comment.dart';
import 'package:social_feed_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:social_feed_app/features/comments/domain/usecases/delete_comment_usecase.dart';
import 'package:social_feed_app/features/comments/domain/usecases/get_comments_usecase.dart';
import 'package:social_feed_app/features/comments/presentation/stores/comments_store.dart';

class _MockGetCommentsUseCase extends Mock implements GetCommentsUseCase {}

class _MockAddCommentUseCase extends Mock implements AddCommentUseCase {}

class _MockDeleteCommentUseCase extends Mock implements DeleteCommentUseCase {}

void main() {
  late _MockGetCommentsUseCase getCommentsUseCase;
  late _MockAddCommentUseCase addCommentUseCase;
  late _MockDeleteCommentUseCase deleteCommentUseCase;
  late CommentsStore store;

  Comment buildComment({required String id, String content = 'A comment'}) {
    return Comment(
      id: id,
      postId: 'post-1',
      authorId: 'user-1',
      authorName: 'Ada Lovelace',
      content: content,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  setUp(() {
    getCommentsUseCase = _MockGetCommentsUseCase();
    addCommentUseCase = _MockAddCommentUseCase();
    deleteCommentUseCase = _MockDeleteCommentUseCase();

    store = CommentsStore(
      getCommentsUseCase: getCommentsUseCase,
      addCommentUseCase: addCommentUseCase,
      deleteCommentUseCase: deleteCommentUseCase,
    );
  });

  group('loadComments', () {
    test('replaces comments and stores the next cursor on success', () async {
      final page = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-1'), buildComment(id: 'comment-2')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => Right(page));

      await store.loadComments('post-1');

      expect(store.comments.map((comment) => comment.id), ['comment-1', 'comment-2']);
      expect(store.error, isNull);
      expect(store.isLoading, isFalse);
      expect(store.hasLoadedOnce, isTrue);
    });

    test('records the failure and leaves comments empty when the load fails', () async {
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Post not found.', statusCode: 404)),
      );

      await store.loadComments('post-1');

      expect(store.comments, isEmpty);
      expect(store.error, const ServerFailure('Post not found.', statusCode: 404));
      expect(store.hasLoadedOnce, isTrue);
    });
  });

  group('loadMore', () {
    test('appends new comments using the stored cursor and updates it', () async {
      final firstPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-1')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => Right(firstPage));
      await store.loadComments('post-1');

      final secondPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-2')],
        nextCursor: null,
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: 'cursor-2', limit: null),
      ).thenAnswer((_) async => Right(secondPage));

      await store.loadMore('post-1');

      expect(store.comments.map((comment) => comment.id), ['comment-1', 'comment-2']);
    });

    test('deduplicates a comment already present from an earlier page', () async {
      final firstPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-1')],
        nextCursor: 'cursor-2',
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => Right(firstPage));
      await store.loadComments('post-1');

      final overlappingPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-1'), buildComment(id: 'comment-2')],
        nextCursor: null,
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: 'cursor-2', limit: null),
      ).thenAnswer((_) async => Right(overlappingPage));

      await store.loadMore('post-1');

      expect(store.comments.map((comment) => comment.id), ['comment-1', 'comment-2']);
    });

    test('is a no-op once there is no further cursor to load', () async {
      final onlyPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-1')],
        nextCursor: null,
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => Right(onlyPage));
      await store.loadComments('post-1');

      await store.loadMore('post-1');

      verify(() => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null)).called(1);
      verifyNever(() => getCommentsUseCase.call(postId: 'post-1', cursor: any(named: 'cursor'), limit: any(named: 'limit')));
    });
  });

  group('addComment', () {
    test('reloads the first page of comments on a successful add', () async {
      when(
        () => addCommentUseCase.call(postId: 'post-1', content: 'Hello'),
      ).thenAnswer((_) async => Right(buildComment(id: 'comment-new', content: 'Hello')));
      final refreshedPage = PaginatedResult<Comment>(
        items: [buildComment(id: 'comment-new', content: 'Hello')],
        nextCursor: null,
      );
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => Right(refreshedPage));

      await store.addComment('post-1', 'Hello');

      expect(store.comments.single.content, 'Hello');
      expect(store.submitError, isNull);
      expect(store.isSubmitting, isFalse);
    });

    test('records a submitError and does not reload comments when the add fails', () async {
      when(
        () => addCommentUseCase.call(postId: 'post-1', content: ''),
      ).thenAnswer(
        (_) async => const Left(ValidationFailure('Comment content cannot be empty.')),
      );

      await store.addComment('post-1', '');

      expect(store.submitError, const ValidationFailure('Comment content cannot be empty.'));
      expect(store.isSubmitting, isFalse);
      verifyNever(
        () => getCommentsUseCase.call(postId: any(named: 'postId'), cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      );
    });
  });

  group('deleteComment', () {
    test('reloads the first page of comments on a successful delete', () async {
      when(() => deleteCommentUseCase.call('comment-1')).thenAnswer((_) async => const Right(null));
      when(
        () => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null),
      ).thenAnswer((_) async => const Right(PaginatedResult<Comment>(items: [], nextCursor: null)));

      await store.deleteComment('comment-1', 'post-1');

      expect(store.comments, isEmpty);
      expect(store.deleteError, isNull);
      expect(store.deletingCommentId, isNull);
      verify(() => getCommentsUseCase.call(postId: 'post-1', cursor: null, limit: null)).called(1);
    });

    test('records a deleteError and does not reload comments when the delete fails', () async {
      when(() => deleteCommentUseCase.call('comment-1')).thenAnswer(
        (_) async => const Left(ServerFailure('Not authorized.', statusCode: 403)),
      );

      await store.deleteComment('comment-1', 'post-1');

      expect(store.deleteError, const ServerFailure('Not authorized.', statusCode: 403));
      expect(store.deletingCommentId, isNull);
      verifyNever(
        () => getCommentsUseCase.call(postId: any(named: 'postId'), cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      );
    });
  });
}
