import 'package:flutter/foundation.dart';

import '../../../../data/models/shift.dart';
import '../../../../data/services/sales_service.dart';

/// Shift history list + detail — mirrors berdikari-web `shift.vue`'s
/// "Riwayat Shift" (uses `GET /sales/shifts` and `GET /sales/shifts/{id}`
/// directly via [SalesService]; no dedicated repository since this is a
/// read-only, screen-local view).
class ShiftHistoryViewModel extends ChangeNotifier {
  ShiftHistoryViewModel({required SalesService salesService})
      : _sales = salesService;

  final SalesService _sales;

  List<CashierShift> _shifts = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  CashierShift? _selected;
  bool _loadingDetail = false;

  List<CashierShift> get shifts => _shifts;
  bool get loading => _loading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  CashierShift? get selected => _selected;
  bool get loadingDetail => _loadingDetail;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _shifts = await _sales.fetchShifts(
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
    } catch (_) {
      _error = 'Gagal memuat data.';
      _shifts = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setStatusFilter(String status) {
    _statusFilter = status;
    return load();
  }

  Future<void> openDetail(String id) async {
    _loadingDetail = true;
    _selected = null;
    notifyListeners();
    try {
      _selected = await _sales.fetchShiftDetail(id);
    } catch (_) {
      _selected = null;
    } finally {
      _loadingDetail = false;
      notifyListeners();
    }
  }

  void closeDetail() {
    _selected = null;
    notifyListeners();
  }
}
