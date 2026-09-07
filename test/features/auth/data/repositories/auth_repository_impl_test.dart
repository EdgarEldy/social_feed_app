import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:social_feed_app/features/auth/data/models/user_model.dart';
import 'package:social_feed_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:social_feed_app/features/auth/domain/entities/auth_session.dart';

class _MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

void main() {
  late _MockAuthRemoteDatasource remoteDatasource;
  late AuthRepositoryImpl repository;

  final userModel = UserModel(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    remoteDatasource = _MockAuthRemoteDatasource();
    repository = AuthRepositoryImpl(remoteDatasource);
  });

  group('register', () {
    test('maps a successful response to an AuthSession wrapping the domain User', () async {
      when(
        () => remoteDatasource.register(
          email: 'ada@example.com',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).thenAnswer(
        (_) async => Right((
          user: userModel,
          accessToken: 'access-123',
          refreshToken: 'refresh-456',
        )),
      );

      final result = await repository.register(
        email: 'ada@example.com',
        password: 'password123',
        displayName: 'Ada Lovelace',
      );

      expect(
        result,
        Right<Failure, AuthSession>(
          AuthSession(
            user: userModel.toEntity(),
            accessToken: 'access-123',
            refreshToken: 'refresh-456',
          ),
        ),
      );
    });

    test('propagates a ServerFailure from the datasource unchanged', () async {
      when(
        () => remoteDatasource.register(
          email: 'ada@example.com',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Email already in use.', statusCode: 409)),
      );

      final result = await repository.register(
        email: 'ada@example.com',
        password: 'password123',
        displayName: 'Ada Lovelace',
      );

      expect(
        result,
        const Left<Failure, AuthSession>(ServerFailure('Email already in use.', statusCode: 409)),
      );
    });
  });

  group('login', () {
    test('maps a successful response to an AuthSession wrapping the domain User', () async {
      when(
        () => remoteDatasource.login(
          email: 'ada@example.com',
          password: 'password123',
        ),
      ).thenAnswer(
        (_) async => Right((
          user: userModel,
          accessToken: 'access-123',
          refreshToken: 'refresh-456',
        )),
      );

      final result = await repository.login(
        email: 'ada@example.com',
        password: 'password123',
      );

      expect(result.isRight(), isTrue);
      final session = result.getOrElse((_) => throw StateError('expected Right'));
      expect(session.user, userModel.toEntity());
      expect(session.accessToken, 'access-123');
      expect(session.refreshToken, 'refresh-456');
    });

    test('propagates a NetworkFailure from the datasource unchanged', () async {
      when(
        () => remoteDatasource.login(
          email: 'ada@example.com',
          password: 'password123',
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );

      final result = await repository.login(
        email: 'ada@example.com',
        password: 'password123',
      );

      expect(
        result,
        const Left<Failure, AuthSession>(NetworkFailure('No connection to the server.')),
      );
    });
  });

  group('refresh', () {
    test('forwards the new access token straight from the datasource', () async {
      when(() => remoteDatasource.refresh('refresh-456')).thenAnswer((_) async => const Right('access-789'));

      final result = await repository.refresh('refresh-456');

      expect(result, const Right<Failure, String>('access-789'));
    });

    test('forwards an UnauthorizedFailure straight from the datasource', () async {
      when(() => remoteDatasource.refresh('stale-refresh')).thenAnswer(
        (_) async => const Left(UnauthorizedFailure('Session expired.')),
      );

      final result = await repository.refresh('stale-refresh');

      expect(result, const Left<Failure, String>(UnauthorizedFailure('Session expired.')));
    });
  });

  group('logout', () {
    test('forwards a successful void response from the datasource', () async {
      when(() => remoteDatasource.logout('refresh-456')).thenAnswer((_) async => const Right(null));

      final result = await repository.logout('refresh-456');

      expect(result, const Right<Failure, void>(null));
    });
  });
}
