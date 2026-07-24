import 'dart:async';

import 'package:flutter/foundation.dart';

import '../local/app_database.dart';
import '../local/sync/sync_status.dart';
import '../models/finance.dart';
import '../services/api_client.dart';
import '../services/client_uuid.dart';
import '../services/finance_service.dart';
import 'auth_repository.dart';

/// Period filter for the finance list — mirrors the presets in berdikari-web
/// `finance/index.vue`'s period tabs (`semua`/`harian`/`mingguan`/`bulanan`/
/// `tahunan`/`kustom`).
enum FinancePeriod { all, today, week, month, year, custom }

/// Cash flow (pemasukan/pengeluaran) — mirrors berdikari-web `finance.ts`.
/// Local-first: [AppDatabase] is the source of truth for every read; the
/// summary is computed locally from cached entries (no network round trip
/// needed to show it). Writes land locally immediately (optimistic UI) and
/// are queued in the outbox for background sync via [pushPending].
/// Business workflow: DNA §5e.
class FinanceRepository extends ChangeNotifier {
  FinanceRepository({
    required FinanceService financeService,
    required AuthRepository authRepository,
    required AppDatabase database,
  })  : _finance = financeService,
        _auth = authRepository,
        _db = database;

  final FinanceService _finance;
  final AuthRepository _auth;
  final AppDatabase _db;
  bool _bootstrapped = false;
  bool _pushing = false;

  List<FinanceEntry> _entries = [];
  FinanceSummary _summary = FinanceSummary.empty;
  bool _loading = false;
  String? _error;
  String _typeFilter = '';
  String _categoryFilter = '';
  FinancePeriod _period = FinancePeriod.all;
  DateTime? _customFrom;
  DateTime? _customTo;

  List<FinanceEntry> get entries => _entries;
  FinanceSummary get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  String get typeFilter => _typeFilter;
  String get categoryFilter => _categoryFilter;
  FinancePeriod get period => _period;
  DateTime? get customFrom => _customFrom;
  DateTime? get customTo => _customTo;
  int get pendingCount => _db.pendingCountFor('finance_entry');

  /// Categories present within the current period's entries — mirrors
  /// berdikari-web's `availableCategories` (period-scoped, ignores the
  /// category filter itself so switching category never shrinks the list).
  List<String> get availableCategories {
    final (from, to) = _range;
    final cats = <String>{
      for (final e in _db.getFinanceEntries())
        if (_withinRange(e.occurredAt, from, to)) e.category,
    };
    return cats.toList()..sort();
  }

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
      case FinancePeriod.year:
        return (_isoDate(DateTime(today.year, 1, 1)), _isoDate(today));
      case FinancePeriod.custom:
        return (
          _customFrom == null ? null : _isoDate(_customFrom!),
          _customTo == null ? null : _isoDate(_customTo!),
        );
    }
  }

  static String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

  bool _withinRange(DateTime date, String? from, String? to) {
    final iso = _isoDate(date);
    if (from != null && iso.compareTo(from) < 0) return false;
    if (to != null && iso.compareTo(to) > 0) return false;
    return true;
  }

  Future<void> fetchAll() async {
    _loading = true;
    _error = null;

    final bootstrapOk = await _ensureBootstrapped();
    if (!bootstrapOk && _db.getFinanceEntries().isEmpty) {
      _error = 'Gagal memuat transaksi.';
    }
    _applyLocalFilters();
    _loading = false;
    notifyListeners();
  }

  /// Local-first lookup for the edit screen — no network round trip, since
  /// the entry is already in the cache the list screen rendered it from.
  FinanceEntry? findById(String id) =>
      _db.getFinanceEntries().where((e) => e.id == id).firstOrNull;

  Future<bool> _ensureBootstrapped() async {
    if (_bootstrapped) return true;
    _bootstrapped = true;
    if (_db.getFinanceEntries().isEmpty) return pullRefresh();
    return true;
  }

  /// Fetches the full entry list from the API and merges it into the local
  /// store (never overwrites a row with unsynced local edits). The summary
  /// is derived locally afterwards — no separate network call needed.
  Future<bool> pullRefresh() async {
    try {
      final entries = await _finance.fetchEntries(businessId: _auth.user?.businessId);
      _db.mergeFinanceEntriesFromServer(entries);
      _applyLocalFilters();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyLocalFilters() {
    final (from, to) = _range;
    final inRange = _db
        .getFinanceEntries()
        .where((e) => _withinRange(e.occurredAt, from, to))
        .toList();
    var filtered = _typeFilter.isEmpty
        ? inRange
        : inRange.where((e) => e.type == _typeFilter).toList();
    if (_categoryFilter.isNotEmpty) {
      filtered = filtered.where((e) => e.category == _categoryFilter).toList();
    }
    _entries = filtered;
    _summary = _computeSummary(inRange);
  }

  FinanceSummary _computeSummary(List<FinanceEntry> rangeEntries) {
    var totalIncome = 0;
    var totalExpense = 0;
    final incomeByCategory = <String, int>{};
    final expenseByCategory = <String, int>{};
    for (final entry in rangeEntries) {
      if (entry.isIncome) {
        totalIncome += entry.amount;
        incomeByCategory[entry.category] = (incomeByCategory[entry.category] ?? 0) + entry.amount;
      } else {
        totalExpense += entry.amount;
        expenseByCategory[entry.category] =
            (expenseByCategory[entry.category] ?? 0) + entry.amount;
      }
    }
    return FinanceSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: totalIncome - totalExpense,
      incomeByCategory: incomeByCategory,
      expenseByCategory: expenseByCategory,
    );
  }

  Future<void> setTypeFilter(String type) {
    _typeFilter = type;
    return fetchAll();
  }

  Future<void> setCategoryFilter(String category) {
    _categoryFilter = category;
    return fetchAll();
  }

  /// Mirrors berdikari-web: switching period resets the category filter,
  /// since categories are scoped to the period and may no longer apply.
  Future<void> setPeriod(FinancePeriod period) {
    _period = period;
    _categoryFilter = '';
    return fetchAll();
  }

  Future<void> setCustomRange({DateTime? from, DateTime? to}) {
    _customFrom = from;
    _customTo = to;
    return fetchAll();
  }

  /// Creates a new entry (`id == null`) or edits an existing manual one
  /// (`id` set) — mirrors `CatalogRepository.saveProduct`'s create/update
  /// unification. Editing a row that hasn't synced yet (still a `local-`
  /// id, `create` job still pending) just rewrites that job's payload in
  /// place — [AppDatabase.enqueue] already collapses same-entity jobs, so
  /// it never turns into a `PUT` against a fake local id.
  Future<FinanceEntry> saveEntry({
    String? id,
    required String type,
    required int amount,
    required String category,
    String? note,
    DateTime? occurredAt,
  }) async {
    await _ensureBootstrapped();
    final isCreate = id == null;
    final current =
        isCreate ? null : _db.getFinanceEntries().where((e) => e.id == id).firstOrNull;
    final clientUuid = generateClientUuid();
    final entityId = id ?? 'local-$clientUuid';
    final entry = FinanceEntry(
      id: entityId,
      type: type,
      amount: amount,
      category: category,
      note: note,
      occurredAt: occurredAt ?? DateTime.now(),
      businessId: _auth.user?.businessId,
      sourceType: current?.sourceType ?? 'manual',
      sourceId: current?.sourceId,
      pendingSync: true,
    );
    _db.putLocalFinanceEntry(
        entry, isCreate ? SyncRowStatus.pendingCreate : SyncRowStatus.pendingUpdate);
    _db.enqueue(
      entityType: 'finance_entry',
      entityId: entityId,
      operation: isCreate ? 'create' : 'update',
      payload: {
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'occurred_at': occurredAt == null ? null : _isoDate(occurredAt),
        if (isCreate) 'client_uuid': clientUuid,
      },
    );
    _applyLocalFilters();
    notifyListeners();
    unawaited(pushPending());
    return entry;
  }

  /// Optimistic delete: hides the entry immediately and queues the server
  /// delete in the background. Known simplification — if the server later
  /// rejects the delete (e.g. a 422 for an auto-generated entry), the row
  /// stays hidden locally rather than being restored; in practice this
  /// path is unreachable from the UI, which never offers delete for
  /// `isAuto` entries.
  Future<void> deleteEntry(String id) async {
    await _ensureBootstrapped();
    if (id.startsWith('local-')) {
      _db.discardPendingJobsFor('finance_entry', id);
      _db.removeFinanceEntry(id);
    } else {
      final current = _db.getFinanceEntries().where((e) => e.id == id).firstOrNull;
      if (current != null) {
        _db.putLocalFinanceEntry(current, SyncRowStatus.pendingDelete);
      }
      _db.enqueue(
        entityType: 'finance_entry',
        entityId: id,
        operation: 'delete',
        payload: const {},
      );
    }
    _applyLocalFilters();
    notifyListeners();
    unawaited(pushPending());
  }

  /// Drains the finance outbox. Stops at the first network-level failure
  /// (leaves the rest queued for the next sync pass); a server rejection
  /// marks just that job `failed` and continues with the rest.
  Future<void> pushPending() async {
    if (_pushing) return;
    _pushing = true;
    try {
      for (final job in _db.pendingJobs('finance_entry')) {
        try {
          if (job.operation == 'delete') {
            await _finance.deleteEntry(job.entityId);
            _db.removeFinanceEntry(job.entityId);
          } else if (job.operation == 'update') {
            final saved = await _finance.updateEntry(
              job.entityId,
              type: job.payload['type'] as String,
              amount: job.payload['amount'] as int,
              category: job.payload['category'] as String,
              note: job.payload['note'] as String?,
              occurredAt: job.payload['occurred_at'] as String?,
            );
            _db.markFinanceEntrySynced(saved);
          } else {
            final saved = await _finance.createEntry(
              businessId: _auth.user?.businessId,
              type: job.payload['type'] as String,
              amount: job.payload['amount'] as int,
              category: job.payload['category'] as String,
              note: job.payload['note'] as String?,
              occurredAt: job.payload['occurred_at'] as String?,
              clientUuid: job.payload['client_uuid'] as String?,
            );
            _db.markFinanceEntrySynced(saved, replacesLocalId: job.entityId);
          }
          _db.markSynced(job.localId);
          _applyLocalFilters();
          notifyListeners();
        } on ApiException catch (e) {
          _db.markFailed(job.localId, e.message);
          notifyListeners();
        } catch (_) {
          break; // network-level failure — retry on the next sync pass.
        }
      }
    } finally {
      _pushing = false;
    }
  }

  /// Records an out-of-till operational expense against an active cashier
  /// shift (`pos.expense`) — does not touch the global [entries] list, so
  /// this stays network-direct rather than going through the local outbox
  /// (it's shift-scoped, not part of the cached Keuangan list).
  Future<FinanceEntry> createShiftExpense({
    required String shiftId,
    required int amount,
    required String category,
    String? note,
  }) =>
      _finance.createEntry(
        businessId: _auth.user?.businessId,
        type: 'expense',
        amount: amount,
        category: category,
        note: note,
        shiftId: shiftId,
      );

  Future<List<FinanceEntry>> fetchShiftExpenses(String shiftId) =>
      _finance.fetchShiftExpenses(shiftId);
}
