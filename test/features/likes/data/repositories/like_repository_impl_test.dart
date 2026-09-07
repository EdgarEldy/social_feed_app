import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/likes/data/datasources/like_remote_datasource.dart';
import 'package:social_feed_app/features/likes/data/models/like_model.dart';
import 'package:social_feed_app/features/likes/data/repositories/like_repository_impl.dart';

class _MockLikeRemoteDatasource extends Mock implements LikeRemoteDatasource {}

void main() {
  late _MockLikeRemoteDatasource remoteDatasource;
  late LikeRepositoryImpl repository;

  setUp(() {
    remoteDatasource = _MockLikeRemoteDatasource();
    repository = LikeRepositoryImpl(remoteDatasource);
  });

  group('toggleLike', () {
    test('maps a successful toggle response to the liked/likesCount record', () async {
      when(() => remoteDatasource.toggleLike('post-1')).thenAnswer(
        (_) async => const Right(LikeToggleModel(liked: true, likesCount: 5)),
      );

      final result = await repository.toggleLike('post-1');

      expect(result.isRight(), isTrue);
      final response = result.getOrElse((_) => throw StateError('expected Right'));
      expect(response.liked, isTrue);
      expect(response.likesCount, 5);
    });

    test('propagates a NetworkFailure from the datasource unchanged', () async {
      when(() => remoteDatasource.toggleLike('post-1')).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );

      final result = await repository.toggleLike('post-1');

      expect(
        result,
        const Left<Failure, ({bool liked, int likesCount})>(NetworkFailure('No connection to the server.')),
      );
    });
  });

  group('getLikeStatus', () {
    test('maps a successful status response to a plain bool', () async {
      when(() => remoteDatasource.getLikeStatus('post-1')).thenAnswer(
        (_) async => const Right(LikeStatusModel(liked: true)),
      );

      final result = await repository.getLikeStatus('post-1');

      expect(result, const Right<Failure, bool>(true));
    });

    test('propagates a ServerFailure from the datasource unchanged', () async {
      when(() => remoteDatasource.getLikeStatus('post-1')).thenAnswer(
        (_) async => const Left(ServerFailure('Post not found.', statusCode: 404)),
      );

      final result = await repository.getLikeStatus('post-1');

      expect(
        result,
        const Left<Failure, bool>(ServerFailure('Post not found.', statusCode: 404)),
      );
    });
  });
}
