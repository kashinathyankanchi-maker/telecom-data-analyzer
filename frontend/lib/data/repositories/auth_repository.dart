// lib/data/repositories/auth_repository.dart
import 'package:telecom_analyzer/core/constants.dart';
import 'package:telecom_analyzer/core/storage.dart';
import 'package:telecom_analyzer/data/models/auth_model.dart';
import 'package:telecom_analyzer/data/repositories/api_client.dart';

class AuthRepository {
  final _client = ApiClient.instance.dio;

  Future<AuthToken> login(String identifier, String password) async {
    return ApiClient.call(() async {
      final response = await _client.post(
        ApiConstants.login,
        data: {'identifier': identifier, 'password': password},
      );
      final token = AuthToken.fromJson(response.data as Map<String, dynamic>);
      await SecureStorage.instance.saveToken(token.accessToken);
      await SecureStorage.instance.saveUserInfo(
        username: token.user.username,
        role: token.user.role,
      );
      return token;
    });
  }

  Future<AuthUser> getMe() async {
    return ApiClient.call(() async {
      final response = await _client.get(ApiConstants.me);
      return AuthUser.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<void> logout() => SecureStorage.instance.clearAll();
}
