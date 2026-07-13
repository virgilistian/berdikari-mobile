import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

enum AuthStatus {
  /// Session restore has not finished yet (app just booted).
  unknown,
  unauthenticated,
  authenticated,
}

/// Single source of truth for the auth session — mirrors the responsibility
/// of berdikari-web's `auth.ts` Pinia store.
///
/// Extends [ChangeNotifier] so the router can re-evaluate redirects
/// (`refreshListenable`) whenever the session changes.
class AuthRepository extends ChangeNotifier {
  AuthRepository({
    required this._service,
    required this._tokenStorage,
  });

  final AuthService _service;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Permission helpers (deny-by-default) ──────────────────────────────

  bool hasPermission(String permission) =>
      _user?.permissions.contains(permission) ?? false;

  bool hasAnyPermission(List<String> permissions) =>
      permissions.any(hasPermission);

  bool hasRole(String role) => _user?.roles.contains(role) ?? false;

  // ── Session lifecycle ─────────────────────────────────────────────────

  /// Restores the session on app start: reads the persisted token and
  /// re-hydrates the user (and their permission set) via `GET /auth/me`.
  /// Any failure clears the session — parity with the web store.
  Future<void> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await _service.me();
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _tokenStorage.clear();
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final session = await _service.login(email: email, password: password);
    await _tokenStorage.write(session.token);
    _user = session.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Best-effort server-side revocation, then always clear locally.
  Future<void> logout() async {
    try {
      await _service.logout();
    } catch (_) {
      // Token may already be invalid — local clear still proceeds.
    }
    await clearSession();
  }

  /// Clears the local session without calling the API. Also wired as the
  /// [ApiClient.onUnauthorized] callback (token expired/revoked mid-use).
  Future<void> clearSession() async {
    await _tokenStorage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Profile ───────────────────────────────────────────────────────────

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    _user = await _service.updateProfile(name: name, email: email);
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) =>
      _service.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
}
