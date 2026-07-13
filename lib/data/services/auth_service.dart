import '../models/auth_user.dart';
import 'api_client.dart';

/// IAM module endpoints (`Modules/IAM/routes/api.php`).
/// All responses use the `{success, data, message}` envelope.
class AuthService {
  AuthService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// `POST /auth/login` — public. Returns the Sanctum token and the user
  /// with `roles[]` and `permissions[]` scoped to their business.
  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = response['data'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  /// `GET /auth/me` — hydrates the session on app start.
  Future<AuthUser> me() async {
    final response = await _api.get('/auth/me');
    return AuthUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `POST /auth/logout` — revokes the current token server-side.
  Future<void> logout() => _api.post('/auth/logout');

  /// `PUT /auth/profile` — updates own name + email, returns the fresh user.
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final response = await _api.put(
      '/auth/profile',
      body: {'name': name, 'email': email},
    );
    return AuthUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `PUT /auth/password`.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) =>
      _api.put(
        '/auth/password',
        body: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
}
