import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../network/dio_client.dart';

/// The app-wide service locator.
///
/// `get_it` is used instead of `InheritedWidget`/`Provider` because it also
/// needs to resolve dependencies from places with no `BuildContext`, such as
/// a `go_router` redirect callback or a `dio` interceptor.
final GetIt getIt = GetIt.instance;

/// Registers every dependency the app needs, in dependency order:
/// datasources first, then repositories, then usecases, then stores. Later
/// branches add to this function as each feature introduces its own
/// datasource/repository/usecase/store; this branch only wires up the
/// cross-cutting infrastructure (`Dio`, `GoRouter`) that everything else
/// will be built on.
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
}
