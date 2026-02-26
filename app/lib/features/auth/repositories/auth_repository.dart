import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _api = ApiClient();

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String displayName,
    String preferredLocale = 'en',
  }) async {
    final response = await _api.register({
      'email': email,
      'password': password,
      'display_name': displayName,
      'preferred_locale': preferredLocale,
    });
    final tokens = AuthTokens.fromJson(response.data);
    await SecureStorage.setTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens;
  }

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.login({
      'email': email,
      'password': password,
    });
    final tokens = AuthTokens.fromJson(response.data);
    await SecureStorage.setTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens;
  }

  Future<User> getMe() async {
    final response = await _api.get(ApiEndpoints.me);
    return User.fromJson(response.data);
  }

  Future<User> updateMe({String? displayName, String? preferredLocale}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (preferredLocale != null) data['preferred_locale'] = preferredLocale;
    final response = await _api.patch(ApiEndpoints.me, data: data);
    return User.fromJson(response.data);
  }

  Future<void> logout() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
      } catch (_) {
        // Best effort — clear tokens regardless
      }
    }
    await SecureStorage.clearAuth();
  }

  Future<bool> hasTokens() async {
    final token = await SecureStorage.getAccessToken();
    return token != null;
  }
}
