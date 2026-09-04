import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network_info/connectivity_store.dart';

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
/// [dioFactory] defaults to [DioClient.create], which requires
/// `dotenv.load()` to have already run. Tests that do not want to load a
/// real `.env` file can pass a lighter factory (e.g. `Dio.new`) while still
/// exercising the same registration wiring as production.
///
/// Must be called once, before `runApp`, so every `getIt<T>()` call made
/// while building the widget tree resolves successfully.
void configureDependencies({Dio Function() dioFactory = DioClient.create}) {
  // registerLazySingleton defers construction until the first getIt<Dio>()
  // call, and reuses that same instance for every call after, so the app
  // never accidentally ends up with two Dio clients holding two different
  // sets of interceptors. The dispose callback lets getIt.reset() (used in
  // tests) actually close the underlying HTTP client instead of leaking it.
  getIt.registerLazySingleton<Dio>(dioFactory, dispose: (dio) => dio.close());

  getIt.registerLazySingleton<GoRouter>(
    buildAppRouter,
    dispose: (router) => router.dispose(),
  );

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

  // core/sync/sync_service.dart's SyncService is deliberately not
  // registered here yet. It needs a real PendingWriteReplayer, and no
  // feature has a concrete *RemoteDatasource for it to replay against
  // until feature/posts/feature/comments are built. Those branches are
  // expected to add the registration here, roughly:
  //
  //   getIt.registerLazySingleton<SyncService>(
  //     () => SyncService(
  //       appDatabase: getIt<AppDatabase>(),
  //       connectivityStore: getIt<ConnectivityStore>(),
  //       replayer: buildPendingWriteReplayer(...),
  //     )..start(),
  //     dispose: (service) => service.dispose(),
  //   );
}
