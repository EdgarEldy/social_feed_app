import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access and refresh JWTs in the platform's secure storage
/// (Keychain on iOS, Keystore on Android) instead of `SharedPreferences`.
///
/// `AuthInterceptor` reads the access token to attach the `Authorization`
/// bearer header to outgoing requests and reads the refresh token when a
/// `401` triggers a silent refresh. `AuthStore` reads both on app start to
/// decide whether a session can be restored without a fresh login, and
/// clears them on sign-out or when a refresh ultimately fails.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  /// Writes both tokens, overwriting whatever was previously stored.
  ///
  /// Called after a successful register/login/refresh response, since all
  /// three return a fresh access/refresh token pair.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Returns the stored access token, or `null` if no session exists yet.
  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  /// Returns the stored refresh token, or `null` if no session exists yet.
  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  /// Deletes both tokens.
  ///
  /// Used on sign-out and by `AuthInterceptor` when a refresh attempt itself
  /// fails, since at that point neither token can be trusted anymore.
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
