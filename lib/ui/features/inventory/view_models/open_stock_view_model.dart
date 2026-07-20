import 'package:flutter/foundation.dart';

import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../data/services/api_client.dart';

class OpenStockLine {
  OpenStockLine({
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.currentStock,
    this.openingQty = 0,
  });

  final String productId;
  final String productName;
  final int? price;
  final String? imageUrl;
  final int currentStock;
  int openingQty;
}

/// State for "Buka Stok" — mirrors berdikari-web `inventory/new.vue`,
/// including future-date prep and prefill from an existing draft.
class OpenStockViewModel extends ChangeNotifier {
  OpenStockViewModel({
    required DailyStockRepository dailyStockRepository,
    String? initialDate,
  })  : _repo = dailyStockRepository,
        _initialDate = initialDate;

  final DailyStockRepository _repo;

  /// Deep-linked date from the draft detail page's "Edit" action
  /// (`?date=YYYY-MM-DD`) — jumps straight to that date instead of the
  /// usual next-open-slot default.
  final String? _initialDate;

  List<OpenStockLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  late String _selectedDate;

  List<OpenStockLine> get lines => _lines;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  String get selectedDate => _selectedDate;
  int get totalOpening => _lines.fold(0, (sum, l) => sum + l.openingQty);
  int get nonZeroCount => _lines.where((l) => l.openingQty > 0).length;
  bool get canSave => totalOpening > 0;

  /// Today is only selectable while it hasn't been opened yet (reopening it
  /// would reset opening/sold/closing back to zero); otherwise the earliest
  /// pickable date is tomorrow, pushing the flow to future-dated prep.
  DateTime get minDate {
    final today = DateTime.parse(DailyStockRepository.today);
    return _repo.hasStocks ? today.add(const Duration(days: 1)) : today;
  }

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    if (!_repo.hasStocks) await _repo.fetchToday();
    _selectedDate = _initialDate ?? _isoDate(minDate);

    final products = await _repo.fetchProducts();
    _lines = products
        .map((p) => OpenStockLine(
              productId: p.id,
              productName: p.name,
              price: p.price,
              imageUrl: p.imageUrl,
              currentStock: p.currentStock,
            ))
        .toList();

    await _applyPrefill(_selectedDate);
    _loading = false;
    notifyListeners();
  }

  Future<void> setDate(String date) async {
    _selectedDate = date;
    notifyListeners();
    await _applyPrefill(date);
    notifyListeners();
  }

  /// Prefill from any stock already prepped for [date] (e.g. reopening a
  /// future date set up earlier); otherwise every line starts at 0.
  Future<void> _applyPrefill(String date) async {
    await _repo.fetchDayDetail(date);
    final byProduct = {for (final s in _repo.dayDetail) s.productId: s.openingQty};
    for (final line in _lines) {
      line.openingQty = byProduct[line.productId] ?? 0;
    }
  }

  static String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

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
      await _repo.openDayFor(_selectedDate, [
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
