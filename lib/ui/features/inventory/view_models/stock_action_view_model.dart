import 'package:flutter/foundation.dart';

import '../../../../data/repositories/stock_repository.dart';
import '../../../../data/services/api_client.dart';

enum StockActionType { receive, adjust }

/// State for the Terima/Sesuaikan bottom sheet on the Stok & Valuasi
/// screen — mirrors berdikari-web `inventory/stock.vue`'s action sheet.
class StockActionViewModel extends ChangeNotifier {
  StockActionViewModel({required StockRepository stockRepository})
      : _repo = stockRepository;

  final StockRepository _repo;

  bool _submitting = false;
  String? _errorMessage;

  bool get submitting => _submitting;
  String? get errorMessage => _errorMessage;

  Future<bool> submit({
    required StockActionType type,
    required String productId,
    required int quantity,
    int? minStock,
    int? currentMinStock,
    String? reason,
  }) async {
    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (type == StockActionType.receive) {
        await _repo.receive(
            productId: productId, quantity: quantity, reason: reason);
      } else {
        await _repo.adjust(
            productId: productId, quantity: quantity, reason: reason);
        if (minStock != null && minStock != currentMinStock) {
          await _repo.setMinStock(productId: productId, minStock: minStock);
        }
      }
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
