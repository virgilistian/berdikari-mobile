import 'package:flutter/foundation.dart';

import '../models/finance.dart';
import '../services/finance_service.dart';
import 'auth_repository.dart';

/// Period filter for the finance list — mirrors the common presets in
/// berdikari-web `finance/index.vue`'s period tabs (subset: this app skips
/// tahunan/kustom to keep the vertical slice small).
enum FinancePeriod { all, today, week, month }

/// Cash flow (pemasukan/pengeluaran) — mirrors berdikari-web `finance.ts`.
/// Business workflow: DNA §5e.
class FinanceRepository extends ChangeNotifier {
  FinanceRepository({
    required FinanceService financeService,
    required AuthRepository authRepository,
  })  : _finance = financeService,
        _auth = authRepository;

  final FinanceService _finance;
  final AuthRepository _auth;

  List<FinanceEntry> _entries = [];
  FinanceSummary _summary = FinanceSummary.empty;
  bool _loading = false;
  String? _error;
  String _typeFilter = '';
  FinancePeriod _period = FinancePeriod.all;

  List<FinanceEntry> get entries => _entries;
  FinanceSummary get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  String get typeFilter => _typeFilter;
  FinancePeriod get period => _period;

  (String?, String?) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case FinancePeriod.all:
        return (null, null);
      case FinancePeriod.today:
        return (_isoDate(today), _isoDate(today));
      case FinancePeriod.week:
        final weekday = today.weekday; // Monday = 1
        final start = today.subtract(Duration(days: weekday - 1));
        return (_isoDate(start), _isoDate(today));
      case FinancePeriod.month:
        final start = DateTime(today.year, today.month, 1);
        return (_isoDate(start), _isoDate(today));
    }
  }

  static String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

  Future<void> fetchAll() async {
    _loading = true;
    _error = null;
    final (from, to) = _range;
    try {
      final results = await Future.wait([
        _finance.fetchEntries(
          businessId: _auth.user?.businessId,
          type: _typeFilter,
          from: from,
          to: to,
        ),
        _finance.fetchSummary(
          businessId: _auth.user?.businessId,
          from: from,
          to: to,
        ),
      ]);
      _entries = results[0] as List<FinanceEntry>;
      _summary = results[1] as FinanceSummary;
    } catch (_) {
      _error = 'Gagal memuat transaksi.';
      _entries = [];
      _summary = FinanceSummary.empty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setTypeFilter(String type) {
    _typeFilter = type;
    return fetchAll();
  }

  Future<void> setPeriod(FinancePeriod period) {
    _period = period;
    return fetchAll();
  }

  Future<FinanceEntry> createEntry({
    required String type,
    required int amount,
    required String category,
    String? note,
  }) async {
    final entry = await _finance.createEntry(
      businessId: _auth.user?.businessId,
      type: type,
      amount: amount,
      category: category,
      note: note,
    );
    await fetchAll();
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    await _finance.deleteEntry(id);
    await fetchAll();
  }
}
