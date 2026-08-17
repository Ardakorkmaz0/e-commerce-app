import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/auth/data/auth_repository.dart';
import 'package:ecommerce_mobile/features/auth/data/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure providers — these are created once and shared app-wide
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());
final apiClientProvider = Provider<ApiClient>((_) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

// AuthNotifier manages the currently signed-in user (or null if signed out).
// Other widgets read `authProvider` to get the user and call methods to change state.
class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // Called once on app start — try to restore an existing session
    return ref.read(authRepositoryProvider).tryRestoreSession();
  }

  // Returns an error message string on failure, null on success
  Future<String?> signIn(
    String username,
    String password, {
    bool remember = false,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(
            username,
            password,
            remember: remember,
          ),
    );
    state = result;
    return _extractError(result);
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
  }) async {
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
            passwordConfirm: passwordConfirm,
            firstName: firstName,
            lastName: lastName,
          ),
    );
    return _extractError(result);
  }

  // Returns an error message on failure, null on success
  Future<String?> updateProfile({
    String? email,
    String? firstName,
    String? lastName,
    String? storeName,
  }) async {
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).updateProfile(
            email: email,
            firstName: firstName,
            lastName: lastName,
            storeName: storeName,
          ),
    );
    if (!result.hasError) state = result;
    return _extractError(result);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  // Extracts a readable message from a DioException or generic error.
  // Uses DioException properties directly instead of parsing toString(),
  // because toString() is unreliable for status codes and case-sensitive.
  String? _extractError(AsyncValue<dynamic> result) {
    if (!result.hasError) return null;
    final error = result.error;

    if (error is DioException) {
      // No network / server not running
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Could not connect to the server. Is the backend running?';
      }

      final statusCode = error.response?.statusCode;

      // 401 → wrong credentials (Django returns this for bad username/password)
      if (statusCode == 401) return 'Incorrect username or password.';

      // 400 → validation error — try to show DRF's field messages
      if (statusCode == 400) {
        final data = error.response?.data;

        // DRF returns JSON like {"password": ["too short", ...]}.
        // A String body means Django returned an HTML error page instead
        // (e.g. DisallowedHost), which is a config problem, not user input.
        if (data is String) {
          return 'Server rejected the request. Check ALLOWED_HOSTS in Django settings.';
        }

        final messages = _flatten(data).join(' ');
        if (messages.isNotEmpty) return messages;

        return 'Invalid data. Please check your input.';
      }

      // 500 → server error
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later.';
      }
    }

    return 'Something went wrong. Please try again.';
  }

  // Recursively collects all leaf strings out of a DRF error body,
  // which may nest lists inside maps (e.g. {"password": ["a", "b"]}).
  List<String> _flatten(dynamic value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) return value.expand(_flatten).toList();
    if (value is Map) return value.values.expand(_flatten).toList();
    return [value.toString()];
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());
