import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late AuthRemoteDatasourceImpl datasource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dioAdapter = DioAdapter(dio: dio);
    datasource = AuthRemoteDatasourceImpl(dio);
  });

  group('login', () {
    test('returns a ServerFailure instead of crashing when a 200 response is missing the documented user field', () async {
      // A 2xx body that does not actually match the documented
      // `{ accessToken, refreshToken, user }` shape throws a TypeError from
      // the `body['user'] as Map<String, dynamic>` cast, which is a subtype
      // of Error rather than Exception. This is exactly the case the bare
      // `catch (_)` in _postForSession was broadened to cover.
      dioAdapter.onPost(
        '/auth/login',
        (server) => server.reply(200, {
          'accessToken': 'access-123',
          'refreshToken': 'refresh-456',
        }),
        data: Matchers.any,
      );

      final result = await datasource.login(
        email: 'ada@example.com',
        password: 'password123',
      );

      switch (result) {
        case Left(value: final failure):
          expect(failure, isA<ServerFailure>());
        case Right():
          fail('expected a Left(ServerFailure), got a Right');
      }
    });
  });

  group('refresh', () {
    test('returns a ServerFailure instead of crashing when a 200 response is missing the documented accessToken field', () async {
      dioAdapter.onPost(
        '/auth/refresh',
        (server) => server.reply(200, <String, dynamic>{}),
        data: Matchers.any,
      );

      final result = await datasource.refresh('stored-refresh-token');

      switch (result) {
        case Left(value: final failure):
          expect(failure, isA<ServerFailure>());
        case Right():
          fail('expected a Left(ServerFailure), got a Right');
      }
    });
  });
}
