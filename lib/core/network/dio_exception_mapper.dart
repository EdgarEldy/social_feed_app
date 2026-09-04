import 'package:dio/dio.dart';

import '../errors/failure.dart';

/// Translates a [DioException] into the domain-level [Failure] it
/// represents.
///
/// Every remote datasource in `data/` funnels its `dio` calls through this
/// function inside a `try`/`catch`, so a [DioException] never crosses out of
/// `data/`. This keeps `domain/` and `presentation/` free of any dependency
/// on `dio`'s exception types.
Failure mapDioExceptionToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure('No connection to the server.');
    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        return const UnauthorizedFailure('Session expired.');
      }
      final data = e.response?.data;
      final serverMessage = (data is Map && data['message'] is String)
          ? data['message'] as String
          : null;
      return ServerFailure(
        serverMessage ?? 'Unexpected server error.',
        statusCode: statusCode,
      );
    default:
      return NetworkFailure(e.message ?? 'Unknown network error.');
  }
}
