import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/app/theme/app_theme.dart';
import 'package:social_feed_app/core/di/injection_container.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/likes/domain/usecases/toggle_like_usecase.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/presentation/widgets/post_card.dart';

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignInWithGoogleUseCase extends Mock
    implements SignInWithGoogleUseCase {}

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockToggleLikeUseCase extends Mock implements ToggleLikeUseCase {}

void main() {
  // PostCard resolves AuthStore (to decide whether to show the author-only
  // menu) and, through its LikeStore, ToggleLikeUseCase straight from
  // get_it, the same setup feed_page_test.dart uses.
  setUp(() {
    final authStore = AuthStore(
      signUpUseCase: _MockSignUpUseCase(),
      signInUseCase: _MockSignInUseCase(),
      signInWithGoogleUseCase: _MockSignInWithGoogleUseCase(),
      signOutUseCase: _MockSignOutUseCase(),
      tokenStorage: _MockSecureTokenStorage(),
      googleSignIn: _MockGoogleSignIn(),
    );
    authStore.updateCurrentUser(
      User(
        id: 'viewer-1',
        displayName: 'Viewer',
        email: 'viewer@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    getIt.registerSingleton<AuthStore>(authStore);
    getIt.registerLazySingleton<ToggleLikeUseCase>(() => _MockToggleLikeUseCase());
  });

  tearDown(() async {
    await getIt.reset();
  });

  final post = Post(
    id: 'post-1',
    authorId: 'author-1',
    authorName: 'Grace Hopper',
    title: 'Debugging is twice as hard as writing the code',
    content:
        'So if you write the code as cleverly as possible, you are, by '
        'definition, not smart enough to debug it. A short tour of how we '
        'keep this codebase boring on purpose.',
    createdAt: DateTime(2026, 3, 4, 9, 30),
    commentsCount: 12,
    likesCount: 48,
    isLikedByMe: true,
  );

  const boundaryKey = Key('post_card_golden_boundary');

  Future<void> pumpPostCard(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // PostCard itself has no RepaintBoundary of its own, so without one
        // here matchesGoldenFile would walk up to the app's root boundary
        // and capture the whole 800x600 test surface instead of just the
        // card. The SizedBox keeps the card at a representative feed-item
        // width, and SingleChildScrollView gives it the unbounded height a
        // real ListView item would get, so its Column (mainAxisSize.max by
        // default) shrink-wraps to its content instead of stretching to
        // fill a bounded Scaffold body the way a plain Center would.
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 400,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: PostCard(post: post),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // PostCard fades and slides itself in on the first post-frame callback;
    // settle that transition so the golden captures the steady state, not
    // whatever partially-transparent frame happened to pump first.
    await tester.pumpAndSettle();
  }

  group('PostCard golden', () {
    testWidgets('matches the light theme reference image', (tester) async {
      await pumpPostCard(tester, AppTheme.light);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/post_card_light.png'),
      );
    });

    testWidgets('matches the dark theme reference image', (tester) async {
      await pumpPostCard(tester, AppTheme.dark);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/post_card_dark.png'),
      );
    });
  });
}
