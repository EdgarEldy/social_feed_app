import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/router/auth_refresh_listenable.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/domain/usecases/sign_up_usecase.dart';
import '../../features/auth/presentation/stores/auth_store.dart';
import '../../features/users/data/datasources/user_remote_datasource.dart';
import '../../features/users/data/repositories/user_repository_impl.dart';
import '../../features/users/domain/repositories/user_repository.dart';
import '../../features/users/domain/usecases/get_user_usecase.dart';
import '../../features/users/domain/usecases/update_user_usecase.dart';
import '../../features/users/domain/usecases/upload_avatar_usecase.dart';
import '../../features/posts/data/datasources/post_local_datasource.dart';
import '../../features/posts/data/datasources/post_remote_datasource.dart';
import '../../features/posts/data/repositories/post_repository_impl.dart';
import '../../features/posts/data/sync/post_pending_write_replayer.dart';
import '../../features/posts/domain/repositories/post_repository.dart';
import '../../features/posts/domain/usecases/create_post_usecase.dart';
import '../../features/posts/domain/usecases/delete_post_usecase.dart';
import '../../features/posts/domain/usecases/get_post_usecase.dart';
import '../../features/posts/domain/usecases/get_posts_usecase.dart';
import '../../features/posts/domain/usecases/update_post_usecase.dart';
import '../../features/posts/presentation/stores/posts_store.dart';
import '../../features/comments/data/datasources/comment_local_datasource.dart';
import '../../features/comments/data/datasources/comment_remote_datasource.dart';
import '../../features/comments/data/repositories/comment_repository_impl.dart';
import '../../features/comments/data/sync/comment_pending_write_replayer.dart';
import '../../features/comments/domain/repositories/comment_repository.dart';
import '../../features/comments/domain/usecases/add_comment_usecase.dart';
import '../../features/comments/domain/usecases/delete_comment_usecase.dart';
import '../../features/comments/domain/usecases/get_comments_usecase.dart';
import '../../features/likes/data/datasources/like_remote_datasource.dart';
import '../../features/likes/data/repositories/like_repository_impl.dart';
import '../../features/likes/domain/repositories/like_repository.dart';
import '../../features/likes/domain/usecases/toggle_like_usecase.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network_info/connectivity_store.dart';
import '../storage/secure_token_storage.dart';
import '../sync/composite_pending_write_replayer.dart';
import '../sync/sync_service.dart';

/// The app-wide service locator.
///
/// `get_it` is used instead of `InheritedWidget`/`Provider` because it also
/// needs to resolve dependencies from places with no `BuildContext`, such as
/// a `go_router` redirect callback or a `dio` interceptor.
final GetIt getIt = GetIt.instance;

/// Registers every dependency the app needs, in dependency order:
/// datasources first, then repositories, then usecases, then stores. Later
/// branches add to this function as each feature introduces its own
/// datasource/repository/usecase/store; so far this wires up the
/// cross-cutting infrastructure (`Dio`, `GoRouter`, `AppDatabase`) that
/// everything else will be built on.
///
/// [dioFactory] defaults to [_defaultDioFactory], which resolves
/// `getIt<SecureTokenStorage>()` and calls [DioClient.create]; this requires
/// `dotenv.load()` to have already run. Tests that do not want to load a
/// real `.env` file can pass a lighter factory (e.g. `Dio.new`) while still
/// exercising the same registration wiring as production.
///
/// Must be called once, before `runApp`, so every `getIt<T>()` call made
/// while building the widget tree resolves successfully.
void configureDependencies({Dio Function() dioFactory = _defaultDioFactory}) {
  // SecureTokenStorage is registered before Dio, since the default Dio
  // factory below needs it to build the AuthInterceptor. registerLazySingleton
  // defers actual construction until first use, so this ordering only
  // matters for readability here, not correctness.
  getIt.registerLazySingleton<SecureTokenStorage>(SecureTokenStorage.new);

  // registerLazySingleton defers construction until the first getIt<Dio>()
  // call, and reuses that same instance for every call after, so the app
  // never accidentally ends up with two Dio clients holding two different
  // sets of interceptors. The dispose callback lets getIt.reset() (used in
  // tests) actually close the underlying HTTP client instead of leaking it.
  getIt.registerLazySingleton<Dio>(dioFactory, dispose: (dio) => dio.close());

  // AppDatabase.database opens the sqflite file lazily on first access, so
  // registering AppDatabase itself can stay synchronous like Dio/GoRouter
  // above; only the first `await getIt<AppDatabase>().database` call pays
  // the cost of opening the file.
  getIt.registerLazySingleton<AppDatabase>(
    AppDatabase.new,
    dispose: (db) => db.close(),
  );

  // ConnectivityStore starts its connectivity check and stream subscription
  // as soon as it is constructed, so registering it lazily still means the
  // first getIt<ConnectivityStore>() call (typically the OfflineBanner
  // wrapper) is what kicks the check off.
  getIt.registerLazySingleton<ConnectivityStore>(
    ConnectivityStore.new,
    dispose: (store) => store.dispose(),
  );

  // feature/auth's remote datasource and repository, registered in the
  // established order: the datasource (needs Dio) first, then the
  // repository (needs the datasource). AuthRepositoryImpl deliberately does
  // not depend on SecureTokenStorage; persisting tokens is the job of the
  // usecases/AuthStore built later in this branch, per AuthRepository's
  // stateless design.
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(getIt<Dio>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthRemoteDatasource>()),
  );

  // feature/users's remote datasource and repository, registered right
  // after auth's for the same reason: the datasource (needs Dio) first,
  // then the repository (needs the datasource). No local datasource here,
  // per UserRepositoryImpl's class doc: a profile read/write has no
  // meaningful cached fallback in this branch's scope.
  getIt.registerLazySingleton<UserRemoteDatasource>(
    () => UserRemoteDatasourceImpl(getIt<Dio>()),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(getIt<UserRemoteDatasource>()),
  );

  // feature/users's three usecases, registered right after UserRepository:
  // each is a thin pass-through to a single repository method, so unlike
  // the auth usecases above they need no other dependency.
  getIt.registerLazySingleton<GetUserUseCase>(
    () => GetUserUseCase(userRepository: getIt<UserRepository>()),
  );
  getIt.registerLazySingleton<UpdateUserUseCase>(
    () => UpdateUserUseCase(userRepository: getIt<UserRepository>()),
  );
  getIt.registerLazySingleton<UploadAvatarUseCase>(
    () => UploadAvatarUseCase(userRepository: getIt<UserRepository>()),
  );

  // The three auth usecases each bridge the stateless AuthRepository and
  // SecureTokenStorage: they persist/clear tokens around the repository
  // call so AuthStore (registered later in this branch) only ever deals
  // with a plain User, never a raw token.
  getIt.registerLazySingleton<SignUpUseCase>(
    () => SignUpUseCase(
      authRepository: getIt<AuthRepository>(),
      tokenStorage: getIt<SecureTokenStorage>(),
    ),
  );
  getIt.registerLazySingleton<SignInUseCase>(
    () => SignInUseCase(
      authRepository: getIt<AuthRepository>(),
      tokenStorage: getIt<SecureTokenStorage>(),
    ),
  );
  getIt.registerLazySingleton<SignOutUseCase>(
    () => SignOutUseCase(
      authRepository: getIt<AuthRepository>(),
      tokenStorage: getIt<SecureTokenStorage>(),
    ),
  );

  // AuthStore is the last piece of the auth dependency chain: it depends on
  // all three usecases above plus SecureTokenStorage directly, for
  // restoreSession's one-shot read of the stored access token (see the
  // store's class doc for why it only reads, never calls a repository
  // method, to restore a session). registerLazySingleton keeps this a
  // single shared instance, resolved both by the widgets that build the
  // login/register forms and by the go_router redirect guard.
  getIt.registerLazySingleton<AuthStore>(
    () => AuthStore(
      signUpUseCase: getIt<SignUpUseCase>(),
      signInUseCase: getIt<SignInUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      tokenStorage: getIt<SecureTokenStorage>(),
    ),
  );

  // AuthRefreshListenable wraps a MobX reaction on AuthStore.isAuthenticated
  // so GoRouter's refreshListenable can react to a sign in/out that happens
  // without a separate navigation event; see its class doc for why go_router
  // needs this bridge at all. It is registered as its own singleton, with
  // its own dispose callback, because GoRouter.dispose() only removes its
  // listener from refreshListenable, it does not dispose the listenable
  // itself.
  getIt.registerLazySingleton<AuthRefreshListenable>(
    () => AuthRefreshListenable(getIt<AuthStore>()),
    dispose: (listenable) => listenable.dispose(),
  );

  // GoRouter is registered after AuthStore/AuthRefreshListenable, now that
  // it depends on both: the redirect guard reads AuthStore.isAuthenticated,
  // and refreshListenable is what makes that guard re-run the moment sign
  // in/out changes that value.
  getIt.registerLazySingleton<GoRouter>(
    () => buildAppRouter(
      authStore: getIt<AuthStore>(),
      refreshListenable: getIt<AuthRefreshListenable>(),
    ),
    dispose: (router) => router.dispose(),
  );

  // feature/posts's remote and local datasources, then the repository that
  // coordinates them, in the same datasource-then-repository order as
  // auth/users above. PostLocalDatasource is registered on its own (not
  // just reached through PostRepository) because the sync replayer below
  // also needs direct access to it, independent of the repository.
  getIt.registerLazySingleton<PostRemoteDatasource>(
    () => PostRemoteDatasourceImpl(getIt<Dio>()),
  );
  getIt.registerLazySingleton<PostLocalDatasource>(
    () => PostLocalDatasource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(
      remoteDatasource: getIt<PostRemoteDatasource>(),
      localDatasource: getIt<PostLocalDatasource>(),
      appDatabase: getIt<AppDatabase>(),
      // Resolved lazily, only when an offline createPost() actually needs
      // it, the same "closure built at the composition root" pattern
      // _defaultDioFactory uses for onSessionExpired below, so PostRepository
      // never itself depends on the presentation-layer AuthStore.
      currentAuthor: () {
        final user = getIt<AuthStore>().currentUser;
        if (user == null) {
          return null;
        }
        return (
          id: user.id,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        );
      },
    ),
  );

  // feature/posts's five usecases, registered right after PostRepository:
  // GetPostsUseCase/GetPostUseCase/UpdatePostUseCase/DeletePostUseCase are
  // thin pass-throughs, same as feature/users's usecases above.
  // CreatePostUseCase is the one exception, validating title/content are
  // non-empty before ever calling the repository; see its class doc.
  getIt.registerLazySingleton<GetPostsUseCase>(
    () => GetPostsUseCase(postRepository: getIt<PostRepository>()),
  );
  getIt.registerLazySingleton<GetPostUseCase>(
    () => GetPostUseCase(postRepository: getIt<PostRepository>()),
  );
  getIt.registerLazySingleton<CreatePostUseCase>(
    () => CreatePostUseCase(postRepository: getIt<PostRepository>()),
  );
  getIt.registerLazySingleton<UpdatePostUseCase>(
    () => UpdatePostUseCase(postRepository: getIt<PostRepository>()),
  );
  getIt.registerLazySingleton<DeletePostUseCase>(
    () => DeletePostUseCase(postRepository: getIt<PostRepository>()),
  );

  // PostsStore backs the single app-wide feed (see its class doc for why
  // that makes it a get_it singleton, unlike UserStore's per-page scoping),
  // so it is registered here right after the usecases it depends on.
  getIt.registerLazySingleton<PostsStore>(
    () => PostsStore(
      getPostsUseCase: getIt<GetPostsUseCase>(),
      getPostUseCase: getIt<GetPostUseCase>(),
      createPostUseCase: getIt<CreatePostUseCase>(),
      deletePostUseCase: getIt<DeletePostUseCase>(),
      updatePostUseCase: getIt<UpdatePostUseCase>(),
    ),
  );

  // feature/comments's remote and local datasources, then the repository
  // that coordinates them, in the same datasource-then-repository order as
  // posts above. CommentLocalDatasource is registered on its own (not just
  // reached through CommentRepository) for the same reason as
  // PostLocalDatasource: the sync replayer below also needs direct access
  // to it, independent of the repository.
  getIt.registerLazySingleton<CommentRemoteDatasource>(
    () => CommentRemoteDatasourceImpl(getIt<Dio>()),
  );
  getIt.registerLazySingleton<CommentLocalDatasource>(
    () => CommentLocalDatasource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<CommentRepository>(
    () => CommentRepositoryImpl(
      remoteDatasource: getIt<CommentRemoteDatasource>(),
      localDatasource: getIt<CommentLocalDatasource>(),
      appDatabase: getIt<AppDatabase>(),
      // Resolved lazily, only when an offline addComment() actually needs
      // it, the exact same "closure built at the composition root" pattern
      // PostRepositoryImpl's currentAuthor uses above.
      currentAuthor: () {
        final user = getIt<AuthStore>().currentUser;
        if (user == null) {
          return null;
        }
        return (
          id: user.id,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        );
      },
    ),
  );

  // feature/comments's three usecases, registered right after
  // CommentRepository, in the same order the Tasks list lists them.
  // GetCommentsUseCase/DeleteCommentUseCase are thin pass-throughs, same as
  // feature/posts's own usecases above. AddCommentUseCase is the one
  // exception, validating content is non-empty before ever calling the
  // repository; see its class doc.
  getIt.registerLazySingleton<GetCommentsUseCase>(
    () => GetCommentsUseCase(commentRepository: getIt<CommentRepository>()),
  );
  getIt.registerLazySingleton<AddCommentUseCase>(
    () => AddCommentUseCase(commentRepository: getIt<CommentRepository>()),
  );
  getIt.registerLazySingleton<DeleteCommentUseCase>(
    () => DeleteCommentUseCase(commentRepository: getIt<CommentRepository>()),
  );

  // feature/likes's remote datasource and repository, registered right
  // after comments' own registrations. There is no local datasource here,
  // same reasoning as UserRepositoryImpl: likes are live-only for this
  // branch's scope, no cache fallback and no pending_writes queueing.
  getIt.registerLazySingleton<LikeRemoteDatasource>(
    () => LikeRemoteDatasourceImpl(getIt<Dio>()),
  );
  getIt.registerLazySingleton<LikeRepository>(
    () => LikeRepositoryImpl(getIt<LikeRemoteDatasource>()),
  );

  // ToggleLikeUseCase is a thin pass-through, same as most other usecases
  // registered above; see its class doc.
  getIt.registerLazySingleton<ToggleLikeUseCase>(
    () => ToggleLikeUseCase(likeRepository: getIt<LikeRepository>()),
  );

  // core/sync/sync_service.dart's SyncService now has a real
  // PendingWriteReplayer to run: feature/posts's own replayer, wrapped in
  // CompositePendingWriteReplayer so a later feature/comments branch can
  // register its own entity-scoped replayer alongside this one without
  // touching either this registration or feature/posts's replayer. Adding
  // feature/comments's own replayer here is exactly the "one line addition"
  // CompositePendingWriteReplayer's own class doc describes.
  getIt.registerLazySingleton<SyncService>(
    () => SyncService(
      appDatabase: getIt<AppDatabase>(),
      connectivityStore: getIt<ConnectivityStore>(),
      replayer: CompositePendingWriteReplayer([
        buildPostPendingWriteReplayer(
          remoteDatasource: getIt<PostRemoteDatasource>(),
          localDatasource: getIt<PostLocalDatasource>(),
        ),
        buildCommentPendingWriteReplayer(
          remoteDatasource: getIt<CommentRemoteDatasource>(),
          localDatasource: getIt<CommentLocalDatasource>(),
        ),
      ]).call,
    )..start(),
    dispose: (service) => service.dispose(),
  );
}

/// The production [Dio] factory used by [configureDependencies].
///
/// Pulled out into its own top-level function, rather than an inline
/// closure, because a default parameter value must be a compile-time
/// constant; a plain function reference qualifies, a closure that reaches
/// into [getIt] at the point of declaration does not.
///
/// [DioClient.create] is given an `onSessionExpired` callback that resolves
/// `getIt<AuthStore>()` lazily, only once the callback actually fires (a
/// forced sign-out after a failed silent refresh), not at the time this
/// factory itself runs. That is what avoids a circular dependency: `Dio` is
/// constructed before `AuthStore` is (registration order below), but the
/// closure body is not evaluated until well after both are registered, by
/// which point `getIt<AuthStore>()` resolves fine.
Dio _defaultDioFactory() => DioClient.create(
  tokenStorage: getIt<SecureTokenStorage>(),
  onSessionExpired: () => getIt<AuthStore>().forceSignOut(),
);
