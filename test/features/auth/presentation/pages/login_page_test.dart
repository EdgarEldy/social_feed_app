import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/app/router/app_router.dart';
import 'package:social_feed_app/app/router/auth_refresh_listenable.dart';
import 'package:social_feed_app/core/di/injection_container.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/core/network_info/connectivity_store.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:social_feed_app/features/auth/presentation/pages/login_page.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_posts_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/update_post_usecase.dart';
import 'package:social_feed_app/features/posts/presentation/stores/posts_store.dart';

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignInWithGoogleUseCase extends Mock
    implements SignInWithGoogleUseCase {}

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGetPostsUseCase extends Mock implements GetPostsUseCase {}

class _MockGetPostUseCase extends Mock implements GetPostUseCase {}

class _MockCreatePostUseCase extends Mock implements CreatePostUseCase {}

class _MockDeletePostUseCase extends Mock implements DeletePostUseCase {}

class _MockUpdatePostUseCase extends Mock implements UpdatePostUseCase {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockSignInUseCase signInUseCase;
  late _MockSignUpUseCase signUpUseCase;
  late _MockSignOutUseCase signOutUseCase;
  late _MockSecureTokenStorage tokenStorage;
  late AuthStore authStore;

  final user = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    signInUseCase = _MockSignInUseCase();
    signUpUseCase = _MockSignUpUseCase();
    signOutUseCase = _MockSignOutUseCase();
    tokenStorage = _MockSecureTokenStorage();

    // AuthStore is constructed directly against mocked collaborators rather
    // than resolved through configureDependencies(), keeping this test from
    // needing a real SecureTokenStorage/Dio/.env setup. LoginPage itself
    // still reads getIt<AuthStore>() internally (see its class doc: it
    // deliberately never navigates on its own, relying on the go_router
    // guard instead), so that one instance is registered below rather than
    // wired through get_it end to end.
    authStore = AuthStore(
      signUpUseCase: signUpUseCase,
      signInUseCase: signInUseCase,
      signInWithGoogleUseCase: _MockSignInWithGoogleUseCase(),
      signOutUseCase: signOutUseCase,
      tokenStorage: tokenStorage,
      googleSignIn: _MockGoogleSignIn(),
    );
    getIt.registerSingleton<AuthStore>(authStore);

    // The router navigation test below lands on the real FeedPage once
    // login succeeds, and FeedPage/PostCard resolve PostsStore and
    // ConnectivityStore straight from get_it (see feed_page_test.dart),
    // so both need a registered instance even though this file is not
    // exercising the feed itself.
    final getPostsUseCase = _MockGetPostsUseCase();
    when(
      () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
    ).thenAnswer((_) async => const Right(PaginatedResult<Post>(items: [], nextCursor: null)));
    getIt.registerSingleton<PostsStore>(
      PostsStore(
        getPostsUseCase: getPostsUseCase,
        getPostUseCase: _MockGetPostUseCase(),
        createPostUseCase: _MockCreatePostUseCase(),
        deletePostUseCase: _MockDeletePostUseCase(),
        updatePostUseCase: _MockUpdatePostUseCase(),
      ),
    );

    final connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<ConnectivityStore>(ConnectivityStore(connectivity: connectivity));
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('LoginPage validation', () {
    testWidgets('shows a validation error under each field on an empty submit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginPage(),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      verifyNever(
        () => signInUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('shows an email format error for a non-empty but invalid email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginPage(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'a-real-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      verifyNever(
        () => signInUseCase.call(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  group('LoginPage submission', () {
    testWidgets('a valid submit calls AuthStore.signIn with the entered credentials', (tester) async {
      when(
        () => signInUseCase.call(
          email: 'ada@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => Right(user));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginPage(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'ada@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      verify(
        () => signInUseCase.call(email: 'ada@example.com', password: 'password123'),
      ).called(1);
      expect(authStore.currentUser, user);
      expect(authStore.isAuthenticated, isTrue);
    });

    testWidgets('a failed submit leaves the form on screen and shows the error as a SnackBar', (tester) async {
      when(
        () => signInUseCase.call(
          email: 'ada@example.com',
          password: 'wrong-password',
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('Invalid email or password.', statusCode: 401)));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginPage(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'ada@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(authStore.isAuthenticated, isFalse);
      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('LoginPage navigation on successful sign in', () {
    // LoginPage never navigates itself; it only calls AuthStore.signIn and
    // leaves navigation to the go_router redirect guard reading
    // AuthStore.isAuthenticated (see the class doc on LoginPage and on
    // _authGuard in app_router.dart). Driving the real buildAppRouter here,
    // rather than asserting on authStore.isAuthenticated alone, is what
    // actually proves a successful login lands the user on the feed route,
    // not just that the store's flag flipped.
    testWidgets('lands on the feed route once AuthStore.isAuthenticated flips to true', (tester) async {
      when(
        () => signInUseCase.call(
          email: 'ada@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => Right(user));

      final refreshListenable = AuthRefreshListenable(authStore);
      addTearDown(refreshListenable.dispose);
      final router = buildAppRouter(
        authStore: authStore,
        refreshListenable: refreshListenable,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Log in'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'ada@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(authStore.isAuthenticated, isTrue);
      expect(find.widgetWithText(AppBar, 'Feed'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Log in'), findsNothing);
    });
  });
}
