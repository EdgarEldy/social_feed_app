import 'bootstrap.dart';

/// Entry point for the `development` flavor. Run with:
///
/// ```sh
/// flutter run -t lib/main_development.dart --flavor development
/// ```
///
/// Loads `.env.development`, which points at the local/staging API used
/// while developing, instead of the plain `.env` file.
Future<void> main() async {
  await bootstrap(envFileName: '.env.development');
}
