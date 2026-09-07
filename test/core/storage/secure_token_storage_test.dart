import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/storage/secure_token_storage.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage storage;
  late SecureTokenStorage tokenStorage;

  setUpAll(() {
    registerFallbackValue(
      const AndroidOptions(),
    );
    registerFallbackValue(
      const IOSOptions(),
    );
  });

  setUp(() {
    storage = _MockFlutterSecureStorage();
    tokenStorage = SecureTokenStorage(storage: storage);
  });

  group('saveTokens', () {
    test('writes the access and refresh token under their own keys', () async {
      when(
        () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
      ).thenAnswer((_) async {});

      await tokenStorage.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );

      verify(
        () => storage.write(key: 'auth_access_token', value: 'access-123'),
      ).called(1);
      verify(
        () => storage.write(key: 'auth_refresh_token', value: 'refresh-456'),
      ).called(1);
    });
  });

  group('getAccessToken', () {
    test('reads the access token key and returns its stored value', () async {
      when(() => storage.read(key: 'auth_access_token')).thenAnswer((_) async => 'stored-access');

      final result = await tokenStorage.getAccessToken();

      expect(result, 'stored-access');
    });

    test('returns null when no access token has ever been stored', () async {
      when(() => storage.read(key: 'auth_access_token')).thenAnswer((_) async => null);

      final result = await tokenStorage.getAccessToken();

      expect(result, isNull);
    });
  });

  group('getRefreshToken', () {
    test('reads the refresh token key and returns its stored value', () async {
      when(() => storage.read(key: 'auth_refresh_token')).thenAnswer((_) async => 'stored-refresh');

      final result = await tokenStorage.getRefreshToken();

      expect(result, 'stored-refresh');
    });
  });

  group('clearTokens', () {
    test('deletes both the access and refresh token keys', () async {
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await tokenStorage.clearTokens();

      verify(() => storage.delete(key: 'auth_access_token')).called(1);
      verify(() => storage.delete(key: 'auth_refresh_token')).called(1);
    });
  });
}
