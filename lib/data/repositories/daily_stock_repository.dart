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
}
