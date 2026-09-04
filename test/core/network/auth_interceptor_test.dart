import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/network/auth_interceptor.dart';
import 'package:social_feed_app/core/network/dio_exception_mapper.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

/// Builds the [DioException] a `401` response from the mocked `/protected`
/// route would actually surface as, with a fresh [RequestOptions] standing
/// in for the request currently being retried (`AuthInterceptor.onError`
/// only ever sees `err.requestOptions`, not the specific instance `dio.get`
/// built internally, so this is what it works with in this test).
///
/// The live `RequestOptions` that flows through `AuthInterceptor.onRequest`
/// gets its `Authorization` header attached in place, and that same mutated
/// instance is what `onError` later inspects. `http_mock_adapter`'s
/// `.throws()` cannot reuse that instance, so when a test is standing in for
/// an already-authenticated request whose session expired, [withAuthHeader]
/// must be supplied to reproduce that mutation on the synthetic
/// `RequestOptions` as well.
DioException _unauthorizedException({bool withAuthHeader = false}) {
  final requestOptions = RequestOptions(
    path: '/protected',
    method: 'GET',
    headers: withAuthHeader ? {'Authorization': 'Bearer stale-access-token'} : null,
  );
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: requestOptions, statusCode: 401),
  );
}

/// Same as [_unauthorizedException], but standing in for the `401` a wrong
/// password on `POST /auth/login` would surface as.
DioException _unauthorizedLoginException() {
  final requestOptions = RequestOptions(path: '/auth/login', method: 'POST');
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: requestOptions,
      statusCode: 401,
      data: {'message': 'Invalid email or password.'},
    ),
  );
}

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late _MockSecureTokenStorage tokenStorage;
  late HttpServer refreshServer;
  late String refreshBaseUrl;
  late int refreshCallCount;
  late bool refreshShouldSucceed;
  late bool refreshShouldReturnMalformedBody;

  setUp(() async {
    refreshCallCount = 0;
    refreshShouldSucceed = true;
    refreshShouldReturnMalformedBody = false;

    // AuthInterceptor builds its own standalone Dio for the refresh call
    // (see the interceptor's class doc for why it cannot reuse the
    // intercepted instance), so http_mock_adapter's DioAdapter, which only
    // ever mocks the specific Dio instance handed to it, has no way to reach
    // it. A tiny loopback-only HttpServer stands in for the real backend for
    // that one call instead, while the intercepted `dio` instance below is
    // mocked normally.
    refreshServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    refreshBaseUrl = 'http://${refreshServer.address.address}:${refreshServer.port}';
    refreshServer.listen((request) async {
      if (request.uri.path == '/auth/refresh' && request.method == 'POST') {
        refreshCallCount++;
        if (refreshShouldReturnMalformedBody) {
          // A 2xx body that does not actually carry the documented
          // `{ accessToken }` shape throws a TypeError from the cast in
          // _performRefresh, not a DioException.
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, dynamic>{}));
        } else if (refreshShouldSucceed) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'accessToken': 'new-access-token'}));
        } else {
          request.response.statusCode = 401;
        }
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dioAdapter = DioAdapter(dio: dio);
    tokenStorage = _MockSecureTokenStorage();

    when(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => tokenStorage.clearTokens()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await refreshServer.close(force: true);
  });

  test('retries the original request exactly once with the refreshed token after a 401', () async {
    var accessTokenCallCount = 0;
    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async {
      accessTokenCallCount++;
      // First call attaches the bearer token to the original request,
      // second call attaches it to the retry, after a successful refresh.
      return accessTokenCallCount == 1 ? 'stale-access-token' : 'new-access-token';
    });
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => 'stored-refresh-token');

    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, baseUrl: refreshBaseUrl));

    dioAdapter.onGet(
      '/protected',
      (server) => server.throws(401, _unauthorizedException()),
      headers: {'Authorization': 'Bearer stale-access-token'},
    );
    dioAdapter.onGet(
      '/protected',
      (server) => server.reply(200, {'data': 'ok'}),
      headers: {'Authorization': 'Bearer new-access-token'},
    );

    final response = await dio.get<Map<String, dynamic>>('/protected');

    expect(response.statusCode, 200);
    expect(response.data, {'data': 'ok'});
    expect(accessTokenCallCount, 2);
    expect(refreshCallCount, 1);
    verify(
      () => tokenStorage.saveTokens(
        accessToken: 'new-access-token',
        refreshToken: 'stored-refresh-token',
      ),
    ).called(1);
    verifyNever(() => tokenStorage.clearTokens());
  });

  test('clears tokens and propagates the original error when the refresh itself fails, without retrying', () async {
    refreshShouldSucceed = false;

    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => 'stale-access-token');
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => 'stored-refresh-token');

    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, baseUrl: refreshBaseUrl));

    dioAdapter.onGet(
      '/protected',
      (server) => server.throws(401, _unauthorizedException(withAuthHeader: true)),
      headers: {'Authorization': 'Bearer stale-access-token'},
    );

    DioException? caughtError;
    try {
      await dio.get<Map<String, dynamic>>('/protected');
      fail('expected a DioException to be thrown');
    } on DioException catch (e) {
      caughtError = e;
    }

    expect(caughtError.response?.statusCode, 401);
    expect(refreshCallCount, 1);
    verify(() => tokenStorage.clearTokens()).called(1);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );

    // A refresh that was actually attempted and itself failed is exactly
    // what "session expired" means: the interceptor must have tagged the
    // error so the mapper reports UnauthorizedFailure, not a generic
    // ServerFailure indistinguishable from any other failed request.
    expect(mapDioExceptionToFailure(caughtError), isA<UnauthorizedFailure>());
  });

  test('clears tokens and propagates the original error, without retrying, when the refresh response body does not match the documented shape', () async {
    // A 200 response missing the documented `accessToken` field throws a
    // TypeError from the cast inside _performRefresh, not a DioException.
    // This confirms it is now treated as an ordinary failed refresh instead
    // of escaping uncaught.
    refreshShouldReturnMalformedBody = true;

    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => 'stale-access-token');
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => 'stored-refresh-token');

    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, baseUrl: refreshBaseUrl));

    dioAdapter.onGet(
      '/protected',
      (server) => server.throws(401, _unauthorizedException(withAuthHeader: true)),
      headers: {'Authorization': 'Bearer stale-access-token'},
    );

    DioException? caughtError;
    try {
      await dio.get<Map<String, dynamic>>('/protected');
      fail('expected a DioException to be thrown');
    } on DioException catch (e) {
      caughtError = e;
    }

    expect(caughtError.response?.statusCode, 401);
    expect(refreshCallCount, 1);
    verify(() => tokenStorage.clearTokens()).called(1);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );
    expect(mapDioExceptionToFailure(caughtError), isA<UnauthorizedFailure>());
  });

  test('clears tokens and propagates the original error without calling refresh when no refresh token is stored', () async {
    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => 'stale-access-token');
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => null);

    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, baseUrl: refreshBaseUrl));

    dioAdapter.onGet(
      '/protected',
      (server) => server.throws(401, _unauthorizedException(withAuthHeader: true)),
      headers: {'Authorization': 'Bearer stale-access-token'},
    );

    DioException? caughtError;
    try {
      await dio.get<Map<String, dynamic>>('/protected');
      fail('expected a DioException to be thrown');
    } on DioException catch (e) {
      caughtError = e;
    }

    expect(caughtError.response?.statusCode, 401);
    expect(refreshCallCount, 0);
    verify(() => tokenStorage.clearTokens()).called(1);
    expect(mapDioExceptionToFailure(caughtError), isA<UnauthorizedFailure>());
  });

  test('a retried request that itself comes back 401 maps to UnauthorizedFailure without attempting a second refresh or retry', () async {
    // Stands in for the request AuthInterceptor.onError itself builds when
    // it retries: extra[authInterceptorRetried] already set to true, and
    // carrying the (new, post-refresh) Authorization header onRequest would
    // have attached. http_mock_adapter's .throws() always surfaces the
    // requestOptions baked into the supplied DioException rather than the
    // live one dio.get built (see _unauthorizedException's doc comment), so
    // that state has to be reproduced here directly rather than by actually
    // driving a real refresh-then-retry round trip first.
    final retriedRequestOptions = RequestOptions(
      path: '/protected',
      method: 'GET',
      headers: {'Authorization': 'Bearer new-access-token'},
      extra: {'authInterceptorRetried': true},
    );
    final retriedUnauthorizedException = DioException(
      requestOptions: retriedRequestOptions,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: retriedRequestOptions, statusCode: 401),
    );

    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => 'new-access-token');
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => 'stored-refresh-token');

    var sessionExpiredCallCount = 0;
    var requestCount = 0;
    // Counts every request that actually leaves through `dio`, including any
    // retry AuthInterceptor.onError might issue via `_dio.fetch`, since that
    // retry re-enters this same interceptor chain from the top.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        tokenStorage,
        baseUrl: refreshBaseUrl,
        onSessionExpired: () => sessionExpiredCallCount++,
      ),
    );

    dioAdapter.onGet(
      '/protected',
      (server) => server.throws(401, retriedUnauthorizedException),
      headers: {'Authorization': 'Bearer new-access-token'},
    );

    DioException? caughtError;
    try {
      await dio.get<Map<String, dynamic>>('/protected');
      fail('expected a DioException to be thrown');
    } on DioException catch (e) {
      caughtError = e;
    }

    expect(caughtError.response?.statusCode, 401);
    // Exactly the one request the test itself issued: onError must not have
    // retried a second time.
    expect(requestCount, 1);
    // No refresh attempted at all for an already-retried request.
    expect(refreshCallCount, 0);
    expect(sessionExpiredCallCount, 1);
    verify(() => tokenStorage.clearTokens()).called(1);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );

    final failure = mapDioExceptionToFailure(caughtError);
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure, isNot(isA<ServerFailure>()));
  });

  test('maps a first-attempt 401 with no prior session, such as a wrong password on login, to ServerFailure rather than UnauthorizedFailure', () async {
    // No access token was ever attached (this is the very first request of
    // a fresh app session) and there is no stored refresh token either, so
    // this is not a case of an expired session at all: there was never a
    // session to expire in the first place.
    when(() => tokenStorage.getAccessToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.getRefreshToken()).thenAnswer((_) async => null);

    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, baseUrl: refreshBaseUrl));

    dioAdapter.onPost(
      '/auth/login',
      (server) => server.throws(401, _unauthorizedLoginException()),
      data: Matchers.any,
    );

    DioException? caughtError;
    try {
      await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': 'user@example.com', 'password': 'wrong-password'},
      );
      fail('expected a DioException to be thrown');
    } on DioException catch (e) {
      caughtError = e;
    }

    expect(caughtError.response?.statusCode, 401);
    expect(refreshCallCount, 0);

    expect(mapDioExceptionToFailure(caughtError), isA<ServerFailure>());
  });
}
