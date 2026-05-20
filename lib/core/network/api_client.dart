import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plum_id_mobile/core/constants/app_constants.dart';
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

    print('[apiClientProvider] Using baseUrl: ${AppConstants.apiBaseUrl}');

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': AppConstants.plumidApiKey,
          'X-Auth-Secret': AppConstants.authSecret,
          'X-HMAC-Secret': AppConstants.appHmacSecret,
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
