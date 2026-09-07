import 'bootstrap.dart';

/// Default entry point, used by `flutter run`/`flutter test` when no
/// `-t`/`--target` flavor entry point is specified. It loads the plain
/// `.env` file, matching this project's behavior before flavors existed.
/// For flavor-specific builds, use `main_development.dart` or
/// `main_production.dart` instead (see `android/app/build.gradle.kts` for
/// the matching Android product flavors).
Future<void> main() async {
  await bootstrap(envFileName: '.env');
}
