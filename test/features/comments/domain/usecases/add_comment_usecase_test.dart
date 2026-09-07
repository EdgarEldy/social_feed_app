import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/comments/domain/entities/comment.dart';
import 'package:social_feed_app/features/comments/domain/repositories/comment_repository.dart';
import 'package:social_feed_app/features/comments/domain/usecases/add_comment_usecase.dart';

class _MockCommentRepository extends Mock implements CommentRepository {}

void main() {
  late _MockCommentRepository commentRepository;
  late AddCommentUseCase useCase;

  final comment = Comment(
    id: 'comment-1',
    postId: 'post-1',
    authorId: 'user-1',
    authorName: 'Ada Lovelace',
    content: 'A real comment',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    commentRepository = _MockCommentRepository();
    useCase = AddCommentUseCase(commentRepository: commentRepository);
  });

  group('AddCommentUseCase', () {
    test('rejects empty content without calling the repository', () async {
      final result = await useCase.call(postId: 'post-1', content: '');

      expect(
        result,
        const Left<Failure, Comment>(
          ValidationFailure('Comment content cannot be empty.'),
        ),
      );
      verifyNever(
        () => commentRepository.addComment(
          postId: any(named: 'postId'),
          content: any(named: 'content'),
        ),
      );
    });

    test('rejects whitespace-only content without calling the repository', () async {
      final result = await useCase.call(postId: 'post-1', content: '   \n  ');

      expect(
        result,
        const Left<Failure, Comment>(
          ValidationFailure('Comment content cannot be empty.'),
        ),
      );
      verifyNever(
        () => commentRepository.addComment(
          postId: any(named: 'postId'),
          content: any(named: 'content'),
        ),
      );
    });

    test('forwards valid content to the repository and returns its result', () async {
      when(
        () => commentRepository.addComment(
          postId: 'post-1',
          content: 'A real comment',
        ),
      ).thenAnswer((_) async => Right(comment));

      final result = await useCase.call(
        postId: 'post-1',
        content: 'A real comment',
      );

      expect(result, Right<Failure, Comment>(comment));
      verify(
        () => commentRepository.addComment(
          postId: 'post-1',
          content: 'A real comment',
        ),
      ).called(1);
    });

    test('propagates a failure from the repository unchanged', () async {
      const failure = ServerFailure('Unexpected server error.', statusCode: 500);
      when(
        () => commentRepository.addComment(
          postId: 'post-1',
          content: 'A real comment',
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(
        postId: 'post-1',
        content: 'A real comment',
      );

      expect(result, const Left<Failure, Comment>(failure));
    });
  });
}
