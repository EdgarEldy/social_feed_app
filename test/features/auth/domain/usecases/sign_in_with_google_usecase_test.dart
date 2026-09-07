import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/auth_session.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_with_google_usecase.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockSecureTokenStorage tokenStorage;
  late SignInWithGoogleUseCase useCase;

  final user = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    authRepository = _MockAuthRepository();
    tokenStorage = _MockSecureTokenStorage();
    useCase = SignInWithGoogleUseCase(
      authRepository: authRepository,
      tokenStorage: tokenStorage,
    );

    when(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
  });

  group('SignInWithGoogleUseCase', () {
    test('returns just the User and persists tokens on a successful exchange, the same way SignInUseCase does', () async {
      final session = AuthSession(
        user: user,
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );
      when(
        () => authRepository.signInWithGoogle('google-id-token'),
      ).thenAnswer((_) async => Right(session));

      final result = await useCase.call(idToken: 'google-id-token');

      expect(result, Right<Failure, User>(user));
      verify(
        () => tokenStorage.saveTokens(
          accessToken: 'access-123',
          refreshToken: 'refresh-456',
        ),
      ).called(1);
    });

    test('propagates a ServerFailure unchanged when the email is already registered under a password-based account, without saving tokens', () async {
      // AuthRepository is mocked at this level, so this stands in for the
      // 409-style conflict the real repository would have already mapped
      // from a DioException further down the stack; there is no special
      // merge handling anywhere in this usecase, the failure just passes
      // through exactly like any other auth error.
      const failure = ServerFailure(
        'An account with this email already exists.',
        statusCode: 409,
      );
      when(
        () => authRepository.signInWithGoogle('google-id-token'),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(idToken: 'google-id-token');

      expect(result, const Left<Failure, User>(failure));
      verifyNever(
        () => tokenStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });
  });
}
