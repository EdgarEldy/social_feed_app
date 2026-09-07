import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/likes/domain/repositories/like_repository.dart';
import 'package:social_feed_app/features/likes/domain/usecases/toggle_like_usecase.dart';

class _MockLikeRepository extends Mock implements LikeRepository {}

void main() {
  late _MockLikeRepository likeRepository;
  late ToggleLikeUseCase useCase;

  setUp(() {
    likeRepository = _MockLikeRepository();
    useCase = ToggleLikeUseCase(likeRepository: likeRepository);
  });

  group('ToggleLikeUseCase', () {
    test('returns the liked state and count from a successful toggle to liked', () async {
      when(() => likeRepository.toggleLike('post-1')).thenAnswer(
        (_) async => const Right((liked: true, likesCount: 6)),
      );

      final result = await useCase.call('post-1');

      expect(
        result,
        const Right<Failure, ({bool liked, int likesCount})>((liked: true, likesCount: 6)),
      );
      verify(() => likeRepository.toggleLike('post-1')).called(1);
    });

    test('returns the unliked state and count from a successful toggle to unliked', () async {
      when(() => likeRepository.toggleLike('post-1')).thenAnswer(
        (_) async => const Right((liked: false, likesCount: 5)),
      );

      final result = await useCase.call('post-1');

      expect(
        result,
        const Right<Failure, ({bool liked, int likesCount})>((liked: false, likesCount: 5)),
      );
    });

    test('propagates a failure from the repository unchanged', () async {
      const failure = ServerFailure('Unexpected server error.', statusCode: 500);
      when(() => likeRepository.toggleLike('post-1')).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call('post-1');

      expect(result, const Left<Failure, ({bool liked, int likesCount})>(failure));
    });

    test('propagates a NetworkFailure from the repository unchanged', () async {
      const failure = NetworkFailure('No connection to the server.');
      when(() => likeRepository.toggleLike('post-1')).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call('post-1');

      expect(result, const Left<Failure, ({bool liked, int likesCount})>(failure));
    });
  });
}
