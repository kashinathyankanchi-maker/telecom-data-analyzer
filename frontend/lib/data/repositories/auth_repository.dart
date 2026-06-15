// lib/data/repositories/auth_repository.dart
import '../../../lib/core/constants.dart';
import '../../../lib/core/storage.dart';
import '../models/auth_model.dart';
import 'api_client.dart';

class AuthRepository {
  final _client = ApiClient.instance.dio;

  /// Login with username or email + password.
  /// Saves the token to secure storage on success.
  Future<AuthToken> login(String identifier, String password) async {
    return ApiClient.call(() async {
      final response = await _client.post(
        ApiConstants.login,
        data: {'identifier': identifier, 'password': password},
      );
      final token = AuthToken.fromJson(response.data as Map<String, dynamic>);

      // Persist token and basic user info
      await SecureStorage.instance.saveToken(token.accessToken);
      await SecureStorage.instance.saveUserInfo(
        username: token.user.username,
        role: token.user.role,
      );

      return token;
    });
  }

  /// Fetch the current user profile (validates stored token).
  Future<AuthUser> getMe() async {
    return ApiClient.call(() async {
      final response = await _client.get(ApiConstants.me);
      return AuthUser.fromJson(response.data as Map<String, dynamic>);
    });
  }

  /// Clear all stored credentials.
  Future<void> logout() => SecureStorage.instance.clearAll();
}
