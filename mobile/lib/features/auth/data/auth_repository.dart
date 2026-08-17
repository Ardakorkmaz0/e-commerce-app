import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/auth/data/models/user_model.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  // Adds the Bearer token to each authenticated request
  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // POST /api/v1/auth/token/ → stores tokens → returns current user
  Future<UserModel> signIn(String username, String password) async {
    final response = await _apiClient.dio.post(
      'auth/token/',
      data: {'username': username, 'password': password},
    );
    final access = response.data['access'] as String;
    final refresh = response.data['refresh'] as String;
    await _tokenStorage.writeTokens(accessToken: access, refreshToken: refresh);
    return _fetchUser(access);
  }

  // POST /api/v1/auth/register/ → registers new user
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
  }) async {
    await _apiClient.dio.post(
      'auth/register/',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
  }

  // Tries to restore the session from a stored token on app start.
  // Returns null if there is no token or the token is expired.
  Future<UserModel?> tryRestoreSession() async {
    final access = await _tokenStorage.readAccessToken();
    if (access == null) return null;
    try {
      return await _fetchUser(access);
    } catch (_) {
      await _tokenStorage.clearTokens();
      return null;
    }
  }

  // GET /api/v1/auth/me/
  Future<UserModel> _fetchUser(String accessToken) async {
    final response = await _apiClient.dio.get(
      'auth/me/',
      options: _auth(accessToken),
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // PATCH /api/v1/auth/me/ → updates profile fields
  Future<UserModel> updateProfile({
    String? email,
    String? firstName,
    String? lastName,
    String? storeName,
  }) async {
    final access = await _tokenStorage.readAccessToken();
    if (access == null) throw Exception('Not authenticated');

    final response = await _apiClient.dio.patch(
      'auth/me/',
      data: {
        if (email != null) 'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (storeName != null) 'store_name': storeName,
      },
      options: _auth(access),
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // POST /api/v1/auth/logout/ → blacklists the refresh token, then clears local storage
  Future<void> signOut() async {
    try {
      final refresh = await _tokenStorage.readRefreshToken();
      final access = await _tokenStorage.readAccessToken();
      if (refresh != null) {
        await _apiClient.dio.post(
          'auth/logout/',
          data: {'refresh': refresh},
          options: access != null ? _auth(access) : null,
        );
      }
    } catch (_) {
      // Ignore API errors; local tokens are cleared regardless
    }
    await _tokenStorage.clearTokens();
  }
}
