import 'package:flutter/foundation.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/services/api_client.dart';

/// State for the new cash entry form. Mirrors berdikari-web's
/// `finance/new.vue` `save` flow.
class FinanceFormViewModel extends ChangeNotifier {
  FinanceFormViewModel({required FinanceRepository financeRepository})
      : _finance = financeRepository;

  final FinanceRepository _finance;

  bool _saving = false;
  String? _errorMessage;

  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  Future<FinanceEntry?> submit({
    required String type,
    required int amount,
    required String category,
    String? note,
  }) async {
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _finance.createEntry(
        type: type,
        amount: amount,
        category: category,
        note: note,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
