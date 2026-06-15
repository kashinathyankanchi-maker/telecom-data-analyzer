// lib/data/repositories/api_client.dart
// ─────────────────────────────────────────────────────────────────────────────
// Singleton Dio HTTP client with:
//   - Automatic Bearer token injection from SecureStorage
//   - 401 interception → triggers global logout signal
// ─────────────────────────────────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../lib/core/constants.dart';
import '../../../lib/core/storage.dart';

/// Global callback invoked when the server returns 401 (token expired/invalid).
/// Set by main.dart's auth provider to trigger navigation to the login screen.
typedef OnUnauthorized = void Function();

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout:    const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ));

    // ── Auth interceptor ──────────────────────────────────────────────────────
    // Reads the stored token and injects it as a Bearer header on every request.
    // On 401 response, fires the onUnauthorized callback.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.instance.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          // Token expired or invalid — fire the global logout callback
          _onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[API] $o'),
      ));
    }
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  OnUnauthorized? _onUnauthorized;

  Dio get dio => _dio;

  /// Register the logout handler (called from main.dart's auth provider).
  void setUnauthorizedCallback(OnUnauthorized cb) => _onUnauthorized = cb;

  String _extractMessage(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'HTTP ${e.response!.statusCode}';
    }
    return e.message ?? 'Network error';
  }

  /// Wraps a Dio call and converts DioException → a human-readable Exception.
  static Future<T> call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final msg = instance._extractMessage(e);
      throw Exception(msg);
    }
  }
}
