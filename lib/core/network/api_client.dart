import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plum_id_mobile/core/utils/token_storage.dart';

part 'api_client.g.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Dio get dio => _dio;
}

@riverpod
Future<ApiClient> apiClient(ApiClientRef ref) async {
  print('[apiClientProvider] Getting tokenStorage...');
  try {
    final tokenStorage = await ref.watch(tokenStorageProvider.future);
    print('[apiClientProvider] Got tokenStorage');

    // Web cannot use dart:io Platform checks; use Flutter platform APIs instead.
    final baseUrl =
        kIsWeb
            ? 'http://localhost:8000'
            : (defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:8000'
                : 'http://localhost:8000');
    print('[apiClientProvider] Using baseUrl: $baseUrl');

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print('[apiClientProvider] DIO ERROR: ${e.message}');
          // Handle 401 Unauthorized globally if needed (e.g., to clear token and logout)
          if (e.response?.statusCode == 401) {
            // You could potentially trigger a logout event here
          }
          return handler.next(e);
        },
      ),
    );

    // Add logging interceptor for debugging
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );

    print('[apiClientProvider] ApiClient created successfully');
    return ApiClient(dio);
  } catch (e, stack) {
    print('[apiClientProvider] ERROR: $e');
    print('[apiClientProvider] STACK: $stack');
    rethrow;
  }
}
