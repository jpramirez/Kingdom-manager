import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;

  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor(dio));
  }

  factory ApiClient() {
    _instance ??= ApiClient._();
    return _instance!;
  }

  // Auth endpoints (no token needed)
  Future<Response> register(Map<String, dynamic> data) =>
      dio.post('/auth/register', data: data);

  Future<Response> login(Map<String, dynamic> data) =>
      dio.post('/auth/login', data: data);

  Future<Response> refreshToken(String refreshToken) =>
      dio.post('/auth/refresh', data: {'refresh_token': refreshToken});

  // Generic methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      dio.patch(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  Future<Response> delete(String path) =>
      dio.delete(path);
}
