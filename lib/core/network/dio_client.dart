import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Builds the single [Dio] instance used across the app.
///
/// Every remote datasource depends on this instance (resolved through
/// `get_it` rather than constructed inline), so the base URL, timeouts, and
/// interceptors are configured exactly once in one place.
class DioClient {
  const DioClient._();

  /// Creates a configured [Dio] instance.
  ///
  /// `API_BASE_URL` is read from the loaded `.env` file rather than
  /// hardcoded, so switching backends (local, staging, production) only
  /// requires changing `.env`, never a code change.
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? '',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
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

    return dio;
  }
}
