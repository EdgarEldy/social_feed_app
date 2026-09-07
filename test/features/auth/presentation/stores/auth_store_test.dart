import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignInWithGoogleUseCase extends Mock
    implements SignInWithGoogleUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late _MockSignUpUseCase signUpUseCase;
  late _MockSignInUseCase signInUseCase;
  late _MockSignInWithGoogleUseCase signInWithGoogleUseCase;
  late _MockSignOutUseCase signOutUseCase;
  late _MockSecureTokenStorage tokenStorage;
  late _MockGoogleSignIn googleSignIn;
  late AuthStore authStore;

  final user = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    signUpUseCase = _MockSignUpUseCase();
    signInUseCase = _MockSignInUseCase();
    signInWithGoogleUseCase = _MockSignInWithGoogleUseCase();
    signOutUseCase = _MockSignOutUseCase();
    tokenStorage = _MockSecureTokenStorage();
    googleSignIn = _MockGoogleSignIn();
    when(() => googleSignIn.initialize()).thenAnswer((_) async {});
    authStore = AuthStore(
      signUpUseCase: signUpUseCase,
      signInUseCase: signInUseCase,
      signInWithGoogleUseCase: signInWithGoogleUseCase,
      signOutUseCase: signOutUseCase,
      tokenStorage: tokenStorage,
      googleSignIn: googleSignIn,
    );
  });

  group('restoreSession', () {
    test('sets hasStoredSession and isAuthenticated when a stored access token exists', () async {
      when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => 'stored-access-token');

      expect(authStore.isRestoringSession, isFalse);
      final future = authStore.restoreSession();
      expect(authStore.isRestoringSession, isTrue);
      await future;

      expect(authStore.isRestoringSession, isFalse);
      expect(authStore.hasStoredSession, isTrue);
      expect(authStore.isAuthenticated, isTrue);
      expect(authStore.currentUser, isNull);
    });

    test('leaves hasStoredSession false when no access token is stored', () async {
      when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => null);

      await authStore.restoreSession();

      expect(authStore.hasStoredSession, isFalse);
      expect(authStore.isAuthenticated, isFalse);
    });
  });

  group('signUp', () {
    test('populates currentUser and hasStoredSession on a successful registration', () async {
      when(
        () => signUpUseCase.call(
          email: 'ada@example.com',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).thenAnswer((_) async => Right(user));

      await authStore.signUp(
        email: 'ada@example.com',
        password: 'password123',
        displayName: 'Ada Lovelace',
      );

      expect(authStore.currentUser, user);
      expect(authStore.hasStoredSession, isTrue);
      expect(authStore.isAuthenticated, isTrue);
      expect(authStore.lastError, isNull);
      expect(authStore.isSubmitting, isFalse);
    });

    test('records the failure and leaves the session unauthenticated on a failed registration', () async {
      when(
        () => signUpUseCase.call(
          email: 'ada@example.com',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Email already in use.', statusCode: 409)),
      );

      await authStore.signUp(
        email: 'ada@example.com',
        password: 'password123',
        displayName: 'Ada Lovelace',
      );

      expect(authStore.currentUser, isNull);
      expect(authStore.isAuthenticated, isFalse);
      expect(authStore.lastError, const ServerFailure('Email already in use.', statusCode: 409));
    });

    test('clears a previous lastError at the start of a new attempt', () async {
      when(
        () => signUpUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('boom', statusCode: 500)));
      await authStore.signUp(email: 'a@a.com', password: 'x', displayName: 'A');
      expect(authStore.lastError, isNotNull);

      when(
        () => signUpUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => Right(user));
      await authStore.signUp(email: 'a@a.com', password: 'x', displayName: 'A');

      expect(authStore.lastError, isNull);
    });
  });

  group('signInWithGoogle', () {
    test('populates currentUser and hasStoredSession on a successful exchange, the same way signIn does', () async {
      final account = _MockGoogleSignInAccount();
      when(() => account.authentication).thenReturn(
        const GoogleSignInAuthentication(idToken: 'google-id-token'),
      );
      when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
      when(
        () => signInWithGoogleUseCase.call(idToken: 'google-id-token'),
      ).thenAnswer((_) async => Right(user));

      await authStore.signInWithGoogle();

      expect(authStore.currentUser, user);
      expect(authStore.hasStoredSession, isTrue);
      expect(authStore.isAuthenticated, isTrue);
      expect(authStore.lastError, isNull);
      expect(authStore.isSubmitting, isFalse);
    });

    test('records the failure returned by the usecase without merging into an existing account', () async {
      final account = _MockGoogleSignInAccount();
      when(() => account.authentication).thenReturn(
        const GoogleSignInAuthentication(idToken: 'google-id-token'),
      );
      when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
      const failure = ServerFailure(
        'An account with this email already exists.',
        statusCode: 409,
      );
      when(
        () => signInWithGoogleUseCase.call(idToken: 'google-id-token'),
      ).thenAnswer((_) async => const Left(failure));

      await authStore.signInWithGoogle();

      expect(authStore.currentUser, isNull);
      expect(authStore.isAuthenticated, isFalse);
      expect(authStore.lastError, failure);
    });

    test('swallows a canceled account picker without setting lastError', () async {
      when(() => googleSignIn.authenticate()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      await authStore.signInWithGoogle();

      expect(authStore.lastError, isNull);
      expect(authStore.isAuthenticated, isFalse);
      verifyNever(
        () => signInWithGoogleUseCase.call(idToken: any(named: 'idToken')),
      );
    });
  });

  group('signOut', () {
    test('clears currentUser and hasStoredSession on a successful sign out', () async {
      when(
        () => signInUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(user));
      await authStore.signIn(email: 'ada@example.com', password: 'password123');
      expect(authStore.isAuthenticated, isTrue);

      when(() => signOutUseCase.call()).thenAnswer((_) async => const Right(null));

      await authStore.signOut();

      expect(authStore.currentUser, isNull);
      expect(authStore.hasStoredSession, isFalse);
      expect(authStore.isAuthenticated, isFalse);
    });

    test('records the failure without clearing the session when sign out fails', () async {
      when(
        () => signInUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(user));
      await authStore.signIn(email: 'ada@example.com', password: 'password123');

      when(() => signOutUseCase.call()).thenAnswer(
        (_) async => const Left(NetworkFailure('No connection to the server.')),
      );

      await authStore.signOut();

      expect(authStore.currentUser, user);
      expect(authStore.isAuthenticated, isTrue);
      expect(authStore.lastError, const NetworkFailure('No connection to the server.'));
    });
  });

  group('forceSignOut', () {
    test('clears the in-memory session without calling the sign-out usecase', () {
      authStore.updateCurrentUser(user);

      authStore.forceSignOut();

      expect(authStore.currentUser, isNull);
      expect(authStore.hasStoredSession, isFalse);
      expect(authStore.isAuthenticated, isFalse);
      verifyNever(() => signOutUseCase.call());
    });
  });

  group('updateCurrentUser', () {
    test('replaces currentUser with the given user', () {
      final updated = user.copyWith(displayName: 'Ada L.');

      authStore.updateCurrentUser(updated);

      expect(authStore.currentUser, updated);
    });
  });
}
