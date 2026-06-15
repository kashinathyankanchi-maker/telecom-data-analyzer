// lib/data/models/auth_model.dart
class AuthUser {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    isActive: json['is_active'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    lastLoginAt: json['last_login_at'] != null
        ? DateTime.parse(json['last_login_at'] as String).toLocal()
        : null,
  );

  bool get isAdmin => role == 'admin';
}

class AuthToken {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;

  const AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
    accessToken: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    expiresIn: json['expires_in'] as int,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}
