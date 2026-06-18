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
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username']?.toString() ?? 'Unknown',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? 'user',
    isActive: json['is_active'] as bool? ?? true,
    createdAt: json['created_at'] != null 
        ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now(),
    lastLoginAt: json['last_login_at'] != null
        ? DateTime.tryParse(json['last_login_at'].toString())?.toLocal()
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
    accessToken: json['access_token']?.toString() ?? '',
    tokenType: json['token_type']?.toString() ?? 'bearer',
    expiresIn: (json['expires_in'] as num?)?.toInt() ?? 3600,
    user: json['user'] != null 
        ? AuthUser.fromJson(json['user'] as Map<String, dynamic>)
        : AuthUser(
            id: 0, username: 'Unknown', email: '', role: 'user', 
            isActive: true, createdAt: DateTime.now()
          ),
  );
}
