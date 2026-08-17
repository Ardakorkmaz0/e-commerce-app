import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _rememberKey = 'remember_me';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  /// Whether the last sign-in asked to be remembered.
  ///
  /// Tokens are always written, because the app needs them for API calls
  /// during the session. This flag decides whether they survive a restart:
  /// on the next launch a false value means the session is discarded.
  Future<bool> readRemember() async {
    return (await _storage.read(key: _rememberKey)) == 'true';
  }

  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    bool remember = true,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _rememberKey, value: remember.toString());
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _rememberKey);
  }
}
