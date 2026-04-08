import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plum_id_mobile/core/network/api_client.dart';
import 'package:plum_id_mobile/data/models/user_profile_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_data_source.g.dart';

abstract class AuthRemoteDataSource {
  Future<String> login(String email, String password);
  Future<void> register(String email, String username, String password);
  Future<UserProfileModel> getMe();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<String> login(String email, String password) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {'mail': email, 'password': password},
    );
    return response.data['access_token'] as String;
  }

  @override
  Future<void> register(String email, String username, String password) async {
    try {
      print('[AuthRemoteDataSource.register] Posting to /auth/register');
      print('[AuthRemoteDataSource.register] Email: $email, Username: $username');
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {'mail': email, 'username': username, 'password': password},
      );
      print('[AuthRemoteDataSource.register] Success! Response: ${response.data}');
    } catch (e, stack) {
      print('[AuthRemoteDataSource.register] ERROR: $e');
      print('[AuthRemoteDataSource.register] STACK: $stack');
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> getMe() async {
    final response = await _apiClient.dio.get('/auth/me');
    return UserProfileModel.fromJson(response.data);
  }
}

@riverpod
Future<AuthRemoteDataSource> authRemoteDataSource(Ref ref) async {
  print('[authRemoteDataSourceProvider] Getting apiClient...');
  try {
    final apiClient = await ref.watch(apiClientProvider.future);
    print('[authRemoteDataSourceProvider] Got apiClient, creating AuthRemoteDataSourceImpl');
    return AuthRemoteDataSourceImpl(apiClient);
  } catch (e, stack) {
    print('[authRemoteDataSourceProvider] ERROR: $e');
    print('[authRemoteDataSourceProvider] STACK: $stack');
    rethrow;
  }
}