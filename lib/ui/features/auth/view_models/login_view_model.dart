import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/api_client.dart';

/// Presentation state for the login screen. Field-level messages come from
/// the API's validation bag (already Bahasa Indonesia); [errorMessage] holds
/// the general failure line.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
      : _auth = authRepository;

  final AuthRepository _auth;

  bool _submitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get submitting => _submitting;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  Future<void> submit({required String email, required String password}) async {
    _submitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await _auth.login(email: email.trim(), password: password);
      // Success: the router's refreshListenable redirects away from /login.
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _fieldErrors = e.fieldErrors;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
