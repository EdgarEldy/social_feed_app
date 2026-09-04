import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../storage/secure_token_storage.dart';
import 'auth_interceptor.dart';

/// Builds the single [Dio] instance used across the app.
///
/// Every remote datasource depends on this instance (resolved through
/// `get_it` rather than constructed inline), so the base URL, timeouts, and
/// interceptors are configured exactly once in one place.
class DioClient {
  const DioClient._();

  /// Creates a configured [Dio] instance.
  ///
  /// `API_BASE_URL` and `API_TIMEOUT_SECONDS` are read from the loaded
  /// `.env` file rather than hardcoded, so switching backends (local,
  /// staging, production) or tuning timeouts only requires changing `.env`,
  /// never a code change.
  ///
  /// [tokenStorage] is handed to the [AuthInterceptor] attached below; it is
  /// a required parameter rather than resolved internally via `getIt` so
  /// this factory stays a plain, easily testable function.
  ///
  /// [onSessionExpired], if supplied, is passed straight through to
  /// [AuthInterceptor]'s constructor of the same name; see that class's doc
  /// for why it is a callback rather than a direct `AuthStore` dependency.
  static Dio create({
    required SecureTokenStorage tokenStorage,
    void Function()? onSessionExpired,
  }) {
    // A missing or misspelled key must fail loudly at startup rather than
    // silently pointing Dio at an empty base URL, which would otherwise
    // surface as a confusing connection error much later.
    final baseUrl =
        dotenv.env['API_BASE_URL'] ??
        (throw StateError(
          'API_BASE_URL is not set. Copy .env.example to .env and fill it in.',
        ));

    final timeout = Duration(
      seconds: int.parse(dotenv.env['API_TIMEOUT_SECONDS'] ?? '10'),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );

    // pretty_dio_logger prints full request/response bodies, which is
    // useful during development but noisy and potentially sensitive in a
    // release build, so it is only attached when kDebugMode is true.
    if (kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          compact: true,
        ),
      );
    }

    // Added after the logger above so every request/response the logger
    // prints already reflects what AuthInterceptor did to it (the attached
    // bearer header, or a transparent 401 retry).
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        tokenStorage,
        baseUrl: baseUrl,
        onSessionExpired: onSessionExpired,
      ),
    );

    return dio;
  }
}
