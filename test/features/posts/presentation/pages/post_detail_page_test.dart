import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/di/injection_container.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/core/pagination/paginated_result.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/comments/domain/entities/comment.dart';
import 'package:social_feed_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:social_feed_app/features/comments/domain/usecases/delete_comment_usecase.dart';
import 'package:social_feed_app/features/comments/domain/usecases/get_comments_usecase.dart';
import 'package:social_feed_app/features/posts/domain/entities/post.dart';
import 'package:social_feed_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/get_posts_usecase.dart';
import 'package:social_feed_app/features/posts/domain/usecases/update_post_usecase.dart';
import 'package:social_feed_app/features/posts/presentation/pages/post_detail_page.dart';
import 'package:social_feed_app/features/posts/presentation/stores/posts_store.dart';

class _MockGetPostsUseCase extends Mock implements GetPostsUseCase {}

class _MockGetPostUseCase extends Mock implements GetPostUseCase {}

class _MockCreatePostUseCase extends Mock implements CreatePostUseCase {}

class _MockDeletePostUseCase extends Mock implements DeletePostUseCase {}

class _MockUpdatePostUseCase extends Mock implements UpdatePostUseCase {}

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class _MockGetCommentsUseCase extends Mock implements GetCommentsUseCase {}

class _MockAddCommentUseCase extends Mock implements AddCommentUseCase {}

class _MockDeleteCommentUseCase extends Mock implements DeleteCommentUseCase {}

void main() {
  late _MockUpdatePostUseCase updatePostUseCase;
  late PostsStore postsStore;

  final signedInUser = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  final originalPost = Post(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'Ada Lovelace',
    title: 'Original title',
    content: 'Original content',
    createdAt: DateTime(2026, 1, 1),
    commentsCount: 0,
    likesCount: 0,
    isLikedByMe: false,
  );

  setUp(() {
    updatePostUseCase = _MockUpdatePostUseCase();

    postsStore = PostsStore(
      getPostsUseCase: _MockGetPostsUseCase(),
      getPostUseCase: _MockGetPostUseCase(),
      createPostUseCase: _MockCreatePostUseCase(),
      deletePostUseCase: _MockDeletePostUseCase(),
      updatePostUseCase: updatePostUseCase,
    )..posts.add(originalPost);
    getIt.registerSingleton<PostsStore>(postsStore);

    final authStore = AuthStore(
      signUpUseCase: _MockSignUpUseCase(),
      signInUseCase: _MockSignInUseCase(),
      signOutUseCase: _MockSignOutUseCase(),
      tokenStorage: _MockSecureTokenStorage(),
    );
    authStore.updateCurrentUser(signedInUser);
    getIt.registerSingleton<AuthStore>(authStore);

    // PostDetailPage now builds its own CommentsStore straight from get_it
    // (see its class doc), pulling in the comments feature's three
    // usecases. They are not central to what this file exercises, so a
    // plain empty-page response is enough to let the page build without a
    // "not registered" GetIt exception.
    final getCommentsUseCase = _MockGetCommentsUseCase();
    when(
      () => getCommentsUseCase.call(
        postId: any(named: 'postId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right(PaginatedResult<Comment>(items: [], nextCursor: null)));
    getIt.registerLazySingleton<GetCommentsUseCase>(() => getCommentsUseCase);
    getIt.registerLazySingleton<AddCommentUseCase>(() => _MockAddCommentUseCase());
    getIt.registerLazySingleton<DeleteCommentUseCase>(() => _MockDeleteCommentUseCase());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpPostDetailPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PostDetailPage(postId: originalPost.id, initialPost: originalPost),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PostDetailPage with an initialPost', () {
    testWidgets('reflects an edit written through PostsStore.updatePost without remounting', (tester) async {
      when(
        () => updatePostUseCase.call('post-1', title: any(named: 'title'), content: any(named: 'content')),
      ).thenAnswer(
        (_) async => Right(originalPost.copyWith(title: 'Updated title')),
      );

      await pumpPostDetailPage(tester);

      expect(find.text('Original title'), findsOneWidget);
      expect(find.text('Updated title'), findsNothing);

      await postsStore.updatePost('post-1', title: 'Updated title');
      await tester.pump();

      expect(find.text('Original title'), findsNothing);
      expect(find.text('Updated title'), findsOneWidget);
    });

    testWidgets('keeps showing initialPost when the edited post is no longer in PostsStore.posts', (tester) async {
      await pumpPostDetailPage(tester);

      postsStore.posts.removeWhere((post) => post.id == 'post-1');
      await tester.pump();

      expect(find.text('Original title'), findsOneWidget);
    });
  });
}
