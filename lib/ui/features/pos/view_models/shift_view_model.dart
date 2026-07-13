import 'package:flutter/foundation.dart';

import '../../../../data/models/shift.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../data/services/api_client.dart';

/// State for the Shift Kasir screen. The shift itself lives in
/// [ShiftRepository]; this holds form submission state and the
/// post-close summary.
class ShiftViewModel extends ChangeNotifier {
  ShiftViewModel({required ShiftRepository shiftRepository})
      : _shift = shiftRepository;

  final ShiftRepository _shift;

  bool _submitting = false;
  String? _errorMessage;
  CashierShift? _closedSummary;

  bool get submitting => _submitting;
  String? get errorMessage => _errorMessage;

  /// Summary (expected cash, difference) shown right after closing.
  CashierShift? get closedSummary => _closedSummary;

  Future<void> init() async {
    if (!_shift.loaded) {
      await _shift.fetchActive();
    }
  }

  void dismissSummary() {
    _closedSummary = null;
    notifyListeners();
  }

  Future<bool> openShift({required int openingCash}) =>
      _run(() => _shift.open(openingCash: openingCash));

  Future<bool> closeShift({required int closingCash, String? note}) =>
      _run(() async {
        _closedSummary =
            await _shift.close(closingCash: closingCash, closingNote: note);
      });

  Future<bool> _run(Future<void> Function() action) async {
    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
