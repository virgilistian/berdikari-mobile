import 'package:flutter/foundation.dart';

import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../data/services/api_client.dart';

class OpenStockLine {
  OpenStockLine({
    required this.productId,
    required this.productName,
    required this.price,
    required this.currentStock,
    this.openingQty = 0,
  });

  final String productId;
  final String productName;
  final int? price;
  final int currentStock;
  int openingQty;
}

/// State for "Buka Stok Hari Ini" — mirrors berdikari-web `inventory/new.vue`.
class OpenStockViewModel extends ChangeNotifier {
  OpenStockViewModel({required DailyStockRepository dailyStockRepository})
      : _repo = dailyStockRepository;

  final DailyStockRepository _repo;

  List<OpenStockLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  List<OpenStockLine> get lines => _lines;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  int get totalOpening => _lines.fold(0, (sum, l) => sum + l.openingQty);
  int get nonZeroCount => _lines.where((l) => l.openingQty > 0).length;
  bool get canSave => totalOpening > 0;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    final products = await _repo.fetchProducts();
    _lines = products
        .map((p) => OpenStockLine(
              productId: p.id,
              productName: p.name,
              price: p.price,
              currentStock: p.currentStock,
            ))
        .toList();
    _loading = false;
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final line = _lines.where((l) => l.productId == productId).firstOrNull;
    if (line == null) return;
    line.openingQty = quantity < 0 ? 0 : quantity;
    notifyListeners();
  }

  void increment(String productId) {
    final line = _lines.where((l) => l.productId == productId).firstOrNull;
    if (line == null) return;
    line.openingQty++;
    notifyListeners();
  }

  void decrement(String productId) {
    final line = _lines.where((l) => l.productId == productId).firstOrNull;
    if (line == null || line.openingQty <= 0) return;
    line.openingQty--;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canSave) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.openDay([
        for (final line in _lines)
          (
            productId: line.productId,
            productName: line.productName,
            openingQty: line.openingQty,
          ),
      ]);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal membuka stok.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
