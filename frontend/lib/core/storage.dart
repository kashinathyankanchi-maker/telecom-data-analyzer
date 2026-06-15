// lib/core/storage.dart
// ─────────────────────────────────────────────────────────────────────────────
// Secure token storage using flutter_secure_storage.
//
// Android  → EncryptedSharedPreferences (AES-256 backed by Android Keystore)
// Windows  → Windows Credential Manager
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _kToken    = 'auth_token';
  static const _kUsername = 'auth_username';
  static const _kRole     = 'auth_role';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardsCompatibility: false),
  );

  // ── Token ──────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);
  Future<String?> getToken()           => _storage.read(key: _kToken);
  Future<void> deleteToken()           => _storage.delete(key: _kToken);

  // ── User info (cached for quick header display) ────────────────────────────
  Future<void> saveUserInfo({required String username, required String role}) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kRole, value: role);
  }

  Future<String?> getUsername() => _storage.read(key: _kUsername);
  Future<String?> getRole()     => _storage.read(key: _kRole);

  // ── Clear all (logout) ─────────────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();
}
