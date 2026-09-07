import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/network/dio_exception_mapper.dart';

RequestOptions _requestOptions({Map<String, dynamic> extra = const {}}) {
  return RequestOptions(path: '/posts', extra: extra);
}

void main() {
  group('mapDioExceptionToFailure', () {
    test('maps a connection timeout to NetworkFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.connectionTimeout,
      );

      expect(
        mapDioExceptionToFailure(exception),
        const NetworkFailure('No connection to the server.'),
      );
    });

    test('maps a receive timeout to NetworkFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.receiveTimeout,
      );

      expect(
        mapDioExceptionToFailure(exception),
        const NetworkFailure('No connection to the server.'),
      );
    });

    test('maps a connection error to NetworkFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.connectionError,
      );

      expect(
        mapDioExceptionToFailure(exception),
        const NetworkFailure('No connection to the server.'),
      );
    });

    test('maps an unrecognized exception type to NetworkFailure using the raw message', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.unknown,
        message: 'Something odd happened.',
      );

      expect(
        mapDioExceptionToFailure(exception),
        const NetworkFailure('Something odd happened.'),
      );
    });

    test('maps an unrecognized exception type with no message to a generic NetworkFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.unknown,
      );

      expect(
        mapDioExceptionToFailure(exception),
        const NetworkFailure('Unknown network error.'),
      );
    });

    test('maps a bad response carrying a server message to ServerFailure with the status code', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 400,
          data: {'message': 'Title is required.'},
        ),
      );

      expect(
        mapDioExceptionToFailure(exception),
        const ServerFailure('Title is required.', statusCode: 400),
      );
    });

    test('maps a bad response with no message body to a generic ServerFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 500,
        ),
      );

      expect(
        mapDioExceptionToFailure(exception),
        const ServerFailure('Unexpected server error.', statusCode: 500),
      );
    });

    test('maps a bad response whose data is not a Map to a generic ServerFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 502,
          data: 'Bad gateway',
        ),
      );

      expect(
        mapDioExceptionToFailure(exception),
        const ServerFailure('Unexpected server error.', statusCode: 502),
      );
    });

    test('maps a 401 tagged with sessionExpired to UnauthorizedFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(extra: {'sessionExpired': true}),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 401,
        ),
      );

      expect(
        mapDioExceptionToFailure(exception),
        const UnauthorizedFailure('Session expired.'),
      );
    });

    test('maps a plain 401 not tagged with sessionExpired to ServerFailure, not UnauthorizedFailure', () {
      final exception = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 401,
          data: {'message': 'Invalid email or password.'},
        ),
      );

      expect(
        mapDioExceptionToFailure(exception),
        const ServerFailure('Invalid email or password.', statusCode: 401),
      );
    });
  });
}
