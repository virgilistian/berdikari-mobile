import 'package:flutter/foundation.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/services/api_client.dart';

/// State for the cash entry create/edit form. Mirrors berdikari-web's
/// `finance/new.vue` `save` flow and `finance/[id].vue`'s edit flow.
class FinanceFormViewModel extends ChangeNotifier {
  FinanceFormViewModel({required FinanceRepository financeRepository, FinanceEntry? existing})
      : _finance = financeRepository,
        editing = existing;

  final FinanceRepository _finance;

  /// Null when creating a new entry.
  final FinanceEntry? editing;

  bool _saving = false;
  String? _errorMessage;

  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  Future<FinanceEntry?> submit({
    required String type,
    required int amount,
    required String category,
    String? note,
    DateTime? occurredAt,
  }) async {
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _finance.saveEntry(
        id: editing?.id,
        type: type,
        amount: amount,
        category: category,
        note: note,
        occurredAt: occurredAt,
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
