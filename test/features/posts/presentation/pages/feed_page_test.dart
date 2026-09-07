import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

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
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/likes/domain/usecases/toggle_like_usecase.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_posts_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/update_post_usecase.dart';
import 'package:social_feed_app/features/posts/presentation/pages/feed_page.dart';
import 'package:social_feed_app/features/posts/presentation/stores/posts_store.dart';
import 'package:social_feed_app/features/posts/presentation/widgets/post_card.dart';

class _MockGetPostsUseCase extends Mock implements GetPostsUseCase {}

class _MockGetPostUseCase extends Mock implements GetPostUseCase {}

class _MockCreatePostUseCase extends Mock implements CreatePostUseCase {}

class _MockDeletePostUseCase extends Mock implements DeletePostUseCase {}

class _MockUpdatePostUseCase extends Mock implements UpdatePostUseCase {}

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignInWithGoogleUseCase extends Mock
    implements SignInWithGoogleUseCase {}

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockConnectivity extends Mock implements Connectivity {}

class _MockToggleLikeUseCase extends Mock implements ToggleLikeUseCase {}

void main() {
  late _MockGetPostsUseCase getPostsUseCase;
  late AuthStore authStore;

  final signedInUser = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  Post buildPost({required String id, required String authorId, required String authorName}) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      title: 'Title for $id',
      content: 'Content for $id',
      createdAt: DateTime(2026, 1, 1),
      commentsCount: 0,
      likesCount: 0,
      isLikedByMe: false,
    );
  }

  final ownPost = buildPost(id: 'post-1', authorId: 'user-1', authorName: 'Ada Lovelace');
  final otherPost1 = buildPost(id: 'post-2', authorId: 'user-2', authorName: 'Grace Hopper');
  final otherPost2 = buildPost(id: 'post-3', authorId: 'user-3', authorName: 'Alan Turing');

  setUp(() {
    getPostsUseCase = _MockGetPostsUseCase();

    // FeedPage/PostCard resolve PostsStore and AuthStore straight from
    // get_it (see their own class docs on why those are get_it singletons
    // rather than constructor-injected), so both need a real instance
    // registered here, built against mocked usecases the same way
    // login_page_test.dart/profile_page_test.dart set up AuthStore.
    getIt.registerSingleton<PostsStore>(
      PostsStore(
        getPostsUseCase: getPostsUseCase,
        getPostUseCase: _MockGetPostUseCase(),
        createPostUseCase: _MockCreatePostUseCase(),
        deletePostUseCase: _MockDeletePostUseCase(),
        updatePostUseCase: _MockUpdatePostUseCase(),
      ),
    );

    authStore = AuthStore(
      signUpUseCase: _MockSignUpUseCase(),
      signInUseCase: _MockSignInUseCase(),
      signInWithGoogleUseCase: _MockSignInWithGoogleUseCase(),
      signOutUseCase: _MockSignOutUseCase(),
      tokenStorage: _MockSecureTokenStorage(),
      googleSignIn: _MockGoogleSignIn(),
    );
    authStore.updateCurrentUser(signedInUser);
    getIt.registerSingleton<AuthStore>(authStore);

    // Only reached by the empty-feed state (see _FeedEmptyState's class
    // doc), but registered for every test here so a stray get_it lookup
    // failure never masks the actual assertion being made.
    final connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<ConnectivityStore>(ConnectivityStore(connectivity: connectivity));

    // Each PostCard now builds its own LikeStore straight from get_it (see
    // its class doc), so it needs ToggleLikeUseCase registered even though
    // none of the tests below tap the LikeButton.
    getIt.registerLazySingleton<ToggleLikeUseCase>(() => _MockToggleLikeUseCase());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpFeedPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FeedPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder postCardFinder(String postId) {
    return find.byWidgetPredicate((widget) => widget is PostCard && widget.post.id == postId);
  }

  group('FeedPage', () {
    testWidgets('renders one PostCard per item returned by GetPostsUseCase', (tester) async {
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResult<Post>(items: [ownPost, otherPost1, otherPost2], nextCursor: null),
        ),
      );

      await pumpFeedPage(tester);

      expect(find.byType(PostCard), findsNWidgets(3));
      expect(postCardFinder('post-1'), findsOneWidget);
      expect(postCardFinder('post-2'), findsOneWidget);
      expect(postCardFinder('post-3'), findsOneWidget);
    });

    testWidgets('shows the author-only menu only on the card authored by the signed-in user', (tester) async {
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResult<Post>(items: [ownPost, otherPost1, otherPost2], nextCursor: null),
        ),
      );

      await pumpFeedPage(tester);

      expect(
        find.descendant(of: postCardFinder('post-1'), matching: find.byIcon(Icons.more_vert)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: postCardFinder('post-2'), matching: find.byIcon(Icons.more_vert)),
        findsNothing,
      );
      expect(
        find.descendant(of: postCardFinder('post-3'), matching: find.byIcon(Icons.more_vert)),
        findsNothing,
      );
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('shows an empty state when the mocked response has no posts', (tester) async {
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Right(PaginatedResult<Post>(items: [], nextCursor: null)));

      await pumpFeedPage(tester);

      expect(find.byType(PostCard), findsNothing);
      expect(find.text('No posts yet. Be the first to share something.'), findsOneWidget);
    });

    testWidgets('shows an ErrorView when loading the feed fails', (tester) async {
      when(
        () => getPostsUseCase.call(cursor: any(named: 'cursor'), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)),
      );

      await pumpFeedPage(tester);

      expect(find.byType(PostCard), findsNothing);
      expect(find.text('Unexpected server error.'), findsOneWidget);
    });
  });
}
