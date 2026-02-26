import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Access Token
  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.keyAccessToken);

  static Future<void> setAccessToken(String token) =>
      _storage.write(key: AppConstants.keyAccessToken, value: token);

  // Refresh Token
  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  static Future<void> setRefreshToken(String token) =>
      _storage.write(key: AppConstants.keyRefreshToken, value: token);

  // Store both tokens
  static Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await setAccessToken(accessToken);
    await setRefreshToken(refreshToken);
  }

  // Clear all auth data
  static Future<void> clearAuth() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
  }
}
