import 'package:flutter/foundation.dart';

import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../data/services/api_client.dart';

/// Wraps [DailyStockRepository] with the close-day action's own
/// submitting/error state — mirrors the ShiftViewModel pattern.
class DailyStockViewModel extends ChangeNotifier {
  DailyStockViewModel({required DailyStockRepository dailyStockRepository})
      : _repo = dailyStockRepository;

  final DailyStockRepository _repo;

  bool _closing = false;
  String? _errorMessage;

  bool get closing => _closing;
  String? get errorMessage => _errorMessage;

  Future<void> init() => _repo.fetchToday();

  Future<void> closeDay() async {
    _closing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.closeDay();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Gagal menutup hari.';
    } finally {
      _closing = false;
      notifyListeners();
    }
  }
}
