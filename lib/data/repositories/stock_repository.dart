import 'package:flutter/foundation.dart';

import '../models/stock.dart';
import '../services/inventory_service.dart';
import 'auth_repository.dart';

/// Stock & valuation — mirrors berdikari-web `inventory.ts`.
/// Business workflow: DNA §5d.
class StockRepository extends ChangeNotifier {
  StockRepository({
    required InventoryService inventoryService,
    required AuthRepository authRepository,
  })  : _inventory = inventoryService,
        _auth = authRepository;

  final InventoryService _inventory;
  final AuthRepository _auth;

  List<StockRow> _rows = [];
  StockSummary? _summary;
  bool _loading = false;
  String? _error;

  List<StockRow> get rows => _rows;
  StockSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  List<StockRow> get lowStockRows => _rows.where((r) => r.isLow).toList();

  // `_loading` flips synchronously but the notify waits until after the
  // first `await` — see the matching note on DailyStockRepository.
  Future<void> fetchStock() async {
    _loading = true;
    _error = null;
    try {
      final (rows, summary) =
          await _inventory.fetchStock(businessId: _auth.user?.businessId);
      _rows = rows;
      _summary = summary;
    } catch (_) {
      _error = 'Gagal memuat stok.';
      _rows = [];
      _summary = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> receive({
    required String productId,
    required int quantity,
    String? reason,
  }) async {
    await _inventory.receive(
      businessId: _auth.user?.businessId,
      productId: productId,
      quantity: quantity,
      reason: reason,
    );
    await fetchStock();
  }

  Future<void> adjust({
    required String productId,
    required int quantity,
    String? reason,
  }) async {
    await _inventory.adjust(
      businessId: _auth.user?.businessId,
      productId: productId,
      quantity: quantity,
      reason: reason,
    );
    await fetchStock();
  }

  Future<void> setMinStock({
    required String productId,
    required int minStock,
  }) async {
    await _inventory.setMinStock(
      businessId: _auth.user?.businessId,
      productId: productId,
      minStock: minStock,
    );
    await fetchStock();
  }

  Future<List<StockMovement>> fetchMovements(String productId) =>
      _inventory.fetchMovements(
        businessId: _auth.user?.businessId,
        productId: productId,
      );
}
