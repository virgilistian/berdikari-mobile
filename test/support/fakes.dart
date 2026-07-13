import 'package:berdikari_mobile/data/models/auth_user.dart';
import 'package:berdikari_mobile/data/repositories/auth_repository.dart';
import 'package:berdikari_mobile/data/services/api_client.dart';
import 'package:berdikari_mobile/data/services/auth_service.dart';
import 'package:berdikari_mobile/data/services/token_storage.dart';

/// Token storage backed by a plain field — no platform channel.
class InMemoryTokenStorage extends TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// AuthService that answers from fixtures instead of HTTP.
class FakeAuthService extends AuthService {
  FakeAuthService({this.user, this.token = 'fake-token', this.loginError})
      : super(apiClient: ApiClient(tokenProvider: () async => null));

  AuthUser? user;
  String token;
  ApiException? loginError;
  bool logoutCalled = false;

  @override
  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final error = loginError;
    if (error != null) throw error;
    return (token: token, user: user!);
  }

  @override
  Future<AuthUser> me() async {
    final current = user;
    if (current == null) {
      throw ApiException(statusCode: 401, message: 'Unauthenticated.');
    }
    return current;
  }

  @override
  Future<void> logout() async => logoutCalled = true;

  @override
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final current = user!;
    user = AuthUser(
      id: current.id,
      name: name,
      email: email,
      role: current.role,
      businessId: current.businessId,
      roles: current.roles,
      permissions: current.permissions,
    );
    return user!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}
}

AuthUser sampleUser({
  List<String> permissions = const ['finance.view', 'pos.view', 'pos.open'],
  List<String> roles = const ['cashier'],
  String name = 'Ibu Sari',
}) =>
    AuthUser(
      id: '1',
      name: name,
      email: 'sari@berdikari.id',
      role: 'cashier',
      businessId: '1',
      roles: roles,
      permissions: permissions,
    );

/// Repository wired to fakes. Seed [token] to simulate a persisted session.
AuthRepository fakeAuthRepository({
  AuthUser? user,
  String? token,
  ApiException? loginError,
}) =>
    AuthRepository(
      service: FakeAuthService(user: user, loginError: loginError),
      tokenStorage: InMemoryTokenStorage(token),
    );
