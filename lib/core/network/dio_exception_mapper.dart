import 'package:dio/dio.dart';

import '../errors/failure.dart';

/// Translates a [DioException] into the domain-level [Failure] it
/// represents.
///
/// Every remote datasource in `data/` funnels its `dio` calls through this
/// function inside a `try`/`catch`, so a [DioException] never crosses out of
/// `data/`. This keeps `domain/` and `presentation/` free of any dependency
/// on `dio`'s exception types.
///
/// A `401` status code is deliberately *not* treated as [UnauthorizedFailure]
/// on its own. Per the `Failure` hierarchy in README.md, [UnauthorizedFailure]
/// means specifically "401 after a failed refresh": [AuthInterceptor]
/// attempted a silent token refresh (or had no refresh token to attempt one
/// with) and gave up, tagging the request's `extra['sessionExpired']` before
/// letting the error propagate. Only that tagged case maps to
/// [UnauthorizedFailure]. Any other `401`, most notably a wrong password on
/// `POST /auth/login`, never goes through the refresh path (there is no
/// access token to have expired yet) and instead falls through to the same
/// generic [ServerFailure] handling every other 4xx/5xx status gets, so
/// callers see it for what it is: a failed request, not an expired session.
Failure mapDioExceptionToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure('No connection to the server.');
    case DioExceptionType.badResponse:
      if (e.requestOptions.extra['sessionExpired'] == true) {
        return const UnauthorizedFailure('Session expired.');
      }
      final statusCode = e.response?.statusCode;
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
