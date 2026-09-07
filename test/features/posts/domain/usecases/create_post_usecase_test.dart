import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/domain/repositories/post_repository.dart';
import 'package:social_feed_app/features/posts/domain/usecases/create_post_usecase.dart';

class _MockPostRepository extends Mock implements PostRepository {}

void main() {
  late _MockPostRepository postRepository;
  late CreatePostUseCase useCase;

  final post = Post(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'Ada Lovelace',
    title: 'A real title',
    content: 'Some real content',
    createdAt: DateTime(2026, 1, 1),
    commentsCount: 0,
    likesCount: 0,
    isLikedByMe: false,
  );

  setUp(() {
    postRepository = _MockPostRepository();
    useCase = CreatePostUseCase(postRepository: postRepository);
  });

  group('CreatePostUseCase', () {
    test('rejects an empty title without calling the repository', () async {
      final result = await useCase.call(title: '', content: 'Some content');

      expect(
        result,
        const Left<Failure, Post>(ValidationFailure('Title cannot be empty.')),
      );
      verifyNever(
        () => postRepository.createPost(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    test('rejects a whitespace-only title without calling the repository', () async {
      final result = await useCase.call(title: '   ', content: 'Some content');

      expect(
        result,
        const Left<Failure, Post>(ValidationFailure('Title cannot be empty.')),
      );
      verifyNever(
        () => postRepository.createPost(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    test('rejects empty content without calling the repository', () async {
      final result = await useCase.call(title: 'A real title', content: '');

      expect(
        result,
        const Left<Failure, Post>(ValidationFailure('Content cannot be empty.')),
      );
      verifyNever(
        () => postRepository.createPost(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    test('rejects whitespace-only content without calling the repository', () async {
      final result = await useCase.call(title: 'A real title', content: '   \n  ');

      expect(
        result,
        const Left<Failure, Post>(ValidationFailure('Content cannot be empty.')),
      );
      verifyNever(
        () => postRepository.createPost(
          title: any(named: 'title'),
          content: any(named: 'content'),
          image: any(named: 'image'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    test('forwards valid title/content to the repository and returns its result', () async {
      when(
        () => postRepository.createPost(
          title: 'A real title',
          content: 'Some real content',
          image: null,
          onSendProgress: null,
        ),
      ).thenAnswer((_) async => Right(post));

      final result = await useCase.call(
        title: 'A real title',
        content: 'Some real content',
      );

      expect(result, Right<Failure, Post>(post));
      verify(
        () => postRepository.createPost(
          title: 'A real title',
          content: 'Some real content',
          image: null,
          onSendProgress: null,
        ),
      ).called(1);
    });

    test('propagates a failure from the repository unchanged', () async {
      const failure = ServerFailure('Unexpected server error.', statusCode: 500);
      when(
        () => postRepository.createPost(
          title: 'A real title',
          content: 'Some real content',
          image: null,
          onSendProgress: null,
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(
        title: 'A real title',
        content: 'Some real content',
      );

      expect(result, const Left<Failure, Post>(failure));
    });
  });
}
