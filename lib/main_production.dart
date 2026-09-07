import 'bootstrap.dart';

/// Entry point for the `production` flavor. Run with:
///
/// ```sh
/// flutter run -t lib/main_production.dart --flavor production
/// ```
///
/// Loads `.env.production`, which points at the live production API,
/// instead of the plain `.env` file.
Future<void> main() async {
  await bootstrap(envFileName: '.env.production');
}
