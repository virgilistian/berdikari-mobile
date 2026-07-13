import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/api_client.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required AuthRepository authRepository})
      : _auth = authRepository;

  final AuthRepository _auth;

  bool _submitting = false;
  bool _saved = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get submitting => _submitting;

  /// Set to true after a successful save; the view shows a snackbar and
  /// must call [consumeSaved] so it fires once.
  bool get saved => _saved;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  void consumeSaved() => _saved = false;

  Future<void> submit({required String name, required String email}) async {
    _submitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await _auth.updateProfile(name: name.trim(), email: email.trim());
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
