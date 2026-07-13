/// Authenticated user as returned by `POST /auth/login` and `GET /auth/me`.
///
/// Mirrors `AuthUser` in berdikari-web `app/stores/auth.ts` — the reference
/// implementation of the API contract. Immutable.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.businessId,
    required this.roles,
    required this.permissions,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        businessId: json['business_id']?.toString(),
        roles: List<String>.from(json['roles'] as List? ?? const []),
        permissions:
            List<String>.from(json['permissions'] as List? ?? const []),
      );

  final String id;
  final String name;
  final String email;

  /// Legacy string column — kept for backward compat with the API.
  final String role;

  final String? businessId;

  /// Spatie role names, e.g. `['business-owner']`.
  final List<String> roles;

  /// Spatie permission strings scoped to the active business,
  /// e.g. `['finance.view', 'pos.open']`.
  final List<String> permissions;
}
