import 'package:flutter/foundation.dart';

import '../models/shift.dart';
import '../services/sales_service.dart';

/// Cashier shift state — mirrors berdikari-web `shift.ts`. The POS screen
/// requires an open shift before checkout (Project DNA §5b).
class ShiftRepository extends ChangeNotifier {
  ShiftRepository({required SalesService salesService})
      : _sales = salesService;

  final SalesService _sales;

  CashierShift? _activeShift;
  bool _loaded = false;

  CashierShift? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift?.isOpen ?? false;

  /// True once [fetchActive] has answered at least once — before that the
  /// POS screen shows a loading state rather than the "no shift" banner.
  bool get loaded => _loaded;

  Future<void> fetchActive() async {
    try {
      _activeShift = await _sales.fetchActiveShift();
    } catch (_) {
      _activeShift = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<CashierShift> open({required int openingCash}) async {
    final shift = await _sales.openShift(openingCash: openingCash);
    _activeShift = shift;
    _loaded = true;
    notifyListeners();
    return shift;
  }

  /// Closes the active shift and returns the summary
  /// (expected cash, difference).
  Future<CashierShift> close({
    required int closingCash,
    String? closingNote,
  }) async {
    final active = _activeShift;
    if (active == null) {
      throw StateError('Tidak ada shift aktif');
    }
    final closed = await _sales.closeShift(
      active.id,
      closingCash: closingCash,
      closingNote: closingNote,
    );
    _activeShift = null;
    notifyListeners();
    return closed;
  }

  /// Called on logout so the next user starts clean.
  void reset() {
    _activeShift = null;
    _loaded = false;
    notifyListeners();
  }
}
