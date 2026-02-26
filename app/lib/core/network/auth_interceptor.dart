import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  // Paths that don't need auth tokens
  static const _publicPaths = [
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.path;
    if (_publicPaths.any((p) => path.endsWith(p))) {
      return handler.next(options);
    }

    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    // Don't retry auth endpoints
    final path = err.requestOptions.path;
    if (_publicPaths.any((p) => path.endsWith(p))) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        await SecureStorage.clearAuth();
        return handler.next(err);
      }

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      await SecureStorage.setTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      // Retry original request with new token
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(options);
      handler.resolve(retryResponse);
    } catch (_) {
      await SecureStorage.clearAuth();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
