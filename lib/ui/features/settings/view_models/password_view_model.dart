import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/api_client.dart';

class PasswordViewModel extends ChangeNotifier {
  PasswordViewModel({required AuthRepository authRepository})
      : _auth = authRepository;

  final AuthRepository _auth;

  bool _submitting = false;
  bool _saved = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get submitting => _submitting;
  bool get saved => _saved;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  void consumeSaved() => _saved = false;

  Future<void> submit({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    _submitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await _auth.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _saved = true;
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
