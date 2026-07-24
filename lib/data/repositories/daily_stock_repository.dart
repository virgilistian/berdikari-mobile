import 'package:flutter/foundation.dart';

import '../models/daily_stock.dart';
import '../services/inventory_service.dart';
import 'auth_repository.dart';

/// Today's stock opname — mirrors berdikari-web `dailyStock.ts`.
/// Business workflow: DNA §5c.
class DailyStockRepository extends ChangeNotifier {
  DailyStockRepository({
    required InventoryService inventoryService,
    required AuthRepository authRepository,
  })  : _inventory = inventoryService,
        _auth = authRepository;

  final InventoryService _inventory;
  final AuthRepository _auth;

  List<DailyStockItem> _stocks = [];
  bool _loading = false;

  List<DailyStockItem> get stocks => _stocks;
  bool get loading => _loading;
  bool get hasStocks => _stocks.isNotEmpty;
  bool get isOpen => _stocks.any((s) => s.status == 'open');
  bool get isClosed => _stocks.isNotEmpty && _stocks.every((s) => s.status == 'closed');

  // `_loading` flips synchronously but the notify waits until after the
  // first `await` — notifying before any suspension point can fire while
  // the caller (typically `ChangeNotifierProvider(create: ...)`) is still
  // mid-build, which Provider forbids for an already-mounted ancestor.
  Future<void> fetchToday() async {
    _loading = true;
    try {
      _stocks = await _inventory.fetchTodayStock(
          businessId: _auth.user?.businessId);
    } catch (_) {
      _stocks = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<ProductForStock>> fetchProducts() =>
      _inventory.fetchStockProducts(businessId: _auth.user?.businessId);

  Future<void> openDay(
      List<({String productId, String productName, int openingQty})> items) async {
    _loading = true;
    try {
      _stocks = await _inventory.openDay(
        businessId: _auth.user?.businessId,
        items: items,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Opens (or re-preps) an arbitrary date — used for future-dated prep from
  /// the "Buka Stok" screen. Only refreshes [stocks] when [date] is today,
  /// mirroring berdikari-web `dailyStock.ts`'s `openDay`.
  Future<List<DailyStockItem>> openDayFor(
    String date,
    List<({String productId, String productName, int openingQty})> items,
  ) async {
    final result = await _inventory.openDayFor(
      businessId: _auth.user?.businessId,
      date: date,
      items: items,
    );
    if (date == today) {
      _stocks = result;
      notifyListeners();
    }
    return result;
  }

  Future<void> closeDay() async {
    _loading = true;
    try {
      _stocks =
          await _inventory.closeDay(businessId: _auth.user?.businessId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static String get today => DateTime.now().toIso8601String().split('T').first;

  List<DailyStockHistoryRow> _history = [];
  bool _historyLoading = false;
  List<DailyStockItem> _dayDetail = [];
  bool _dayDetailLoading = false;

  List<DailyStockHistoryRow> get history => _history;
  bool get historyLoading => _historyLoading;
  List<DailyStockItem> get dayDetail => _dayDetail;
  bool get dayDetailLoading => _dayDetailLoading;

  Future<void> fetchHistory() async {
    _historyLoading = true;
    notifyListeners();
    try {
      _history = await _inventory.fetchHistory(businessId: _auth.user?.businessId);
    } catch (_) {
      _history = [];
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDayDetail(String date) async {
    _dayDetailLoading = true;
    notifyListeners();
    try {
      _dayDetail = await _inventory.fetchDayDetail(
        businessId: _auth.user?.businessId,
        date: date,
      );
    } catch (_) {
      _dayDetail = [];
    } finally {
      _dayDetailLoading = false;
      notifyListeners();
    }
  }

  /// Physical-count correction against today's open stock (e.g. during
  /// shift-close reconciliation). Updates [stocks] in place.
  Future<void> adjustStock(
    String productId,
    int adjustmentQty, {
    String? note,
  }) async {
    final updated = await _inventory.adjustDailyStock(
      businessId: _auth.user?.businessId,
      date: today,
      productId: productId,
      adjustmentQty: adjustmentQty,
      adjustmentNote: note,
    );
    final idx = _stocks.indexWhere((s) => s.productId == productId);
    if (idx != -1) {
      _stocks = [
        for (var i = 0; i < _stocks.length; i++)
          if (i == idx) updated else _stocks[i],
      ];
    }
    notifyListeners();
  }

  /// Deletes a still-draft (future-dated) day.
  Future<void> deleteDay(String date) async {
    await _inventory.deleteDailyStockDay(
      businessId: _auth.user?.businessId,
      date: date,
    );
    _history = _history.where((h) => h.date != date).toList();
    notifyListeners();
  }
}
