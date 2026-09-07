import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/auth/data/models/user_model.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/users/data/datasources/user_remote_datasource.dart';
import 'package:social_feed_app/features/users/data/repositories/user_repository_impl.dart';

class _MockUserRemoteDatasource extends Mock implements UserRemoteDatasource {}

class _FakeFile extends Fake implements File {
  @override
  String get path => 'fake/path.jpg';
}

void main() {
  late _MockUserRemoteDatasource remoteDatasource;
  late UserRepositoryImpl repository;

  final userModel = UserModel(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(_FakeFile());
  });

  setUp(() {
    remoteDatasource = _MockUserRemoteDatasource();
    repository = UserRepositoryImpl(remoteDatasource);
  });

  group('getUser', () {
    test('maps a successful response to the domain User', () async {
      when(() => remoteDatasource.getUser('user-1')).thenAnswer((_) async => Right(userModel));

      final result = await repository.getUser('user-1');

      expect(result, Right<Failure, User>(userModel.toEntity()));
    });

    test('propagates a ServerFailure from the datasource unchanged', () async {
      when(() => remoteDatasource.getUser('user-1')).thenAnswer(
        (_) async => const Left(ServerFailure('User not found.', statusCode: 404)),
      );

      final result = await repository.getUser('user-1');

      expect(result, const Left<Failure, User>(ServerFailure('User not found.', statusCode: 404)));
    });
  });

  group('updateCurrentUser', () {
    test('maps a successful response to the domain User', () async {
      final updated = userModel.copyWith(displayName: 'Ada L.');
      when(() => remoteDatasource.updateCurrentUser(displayName: 'Ada L.')).thenAnswer(
        (_) async => Right(updated),
      );

      final result = await repository.updateCurrentUser(displayName: 'Ada L.');

      expect(result, Right<Failure, User>(updated.toEntity()));
    });

    test('propagates a NetworkFailure from the datasource unchanged', () async {
      when(() => remoteDatasource.updateCurrentUser(displayName: 'Ada L.')).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );

      final result = await repository.updateCurrentUser(displayName: 'Ada L.');

      expect(result, const Left<Failure, User>(NetworkFailure('No connection to the server.')));
    });
  });

  group('uploadAvatar', () {
    test('forwards the photoUrl and progress callback straight from the datasource', () async {
      var progressCalls = 0;
      when(
        () => remoteDatasource.uploadAvatar(
          any(),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onSendProgress = invocation.namedArguments[#onSendProgress]
            as void Function(int, int)?;
        onSendProgress?.call(50, 100);
        return const Right('https://cdn.example.com/avatar.jpg');
      });

      final result = await repository.uploadAvatar(
        _FakeFile(),
        onSendProgress: (sent, total) => progressCalls++,
      );

      expect(result, const Right<Failure, String>('https://cdn.example.com/avatar.jpg'));
      expect(progressCalls, 1);
    });

    test('propagates a ServerFailure from the datasource unchanged', () async {
      when(
        () => remoteDatasource.uploadAvatar(any(), onSendProgress: any(named: 'onSendProgress')),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)),
      );

      final result = await repository.uploadAvatar(_FakeFile());

      expect(
        result,
        const Left<Failure, String>(ServerFailure('Unexpected server error.', statusCode: 500)),
      );
    });
  });
}
