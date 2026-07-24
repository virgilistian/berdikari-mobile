import 'package:flutter/foundation.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/shift_repository.dart';

/// State for the POS screen: product grid + category pills. Cart state
/// lives in [CartRepository]; shift gating in [ShiftRepository].
class PosViewModel extends ChangeNotifier {
  PosViewModel({
    required CatalogRepository catalogRepository,
    required ShiftRepository shiftRepository,
  })  : _catalog = catalogRepository,
        _shift = shiftRepository;

  final CatalogRepository _catalog;
  final ShiftRepository _shift;

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  bool _shiftReminderDismissed = false;

  List<ProductCategory> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;
  String? get error => _error;

  List<Product> get visibleProducts {
    var list = _selectedCategoryId == null
        ? _products
        : _products.where((p) => p.categoryId == _selectedCategoryId).toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(query)).toList();
    }
    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Dismissible for the rest of this screen session — mirrors
  /// berdikari-web `pos/index.vue`'s per-day reminder dismissal (kept
  /// simpler here: dismissed until the POS screen is next recreated).
  bool get showShiftReminder => !_shift.hasActiveShift && !_shiftReminderDismissed;

  void dismissShiftReminder() {
    _shiftReminderDismissed = true;
    notifyListeners();
  }

  Future<void> init() async {
    if (!_shift.loaded) {
      await _shift.fetchActive();
    }
    await loadCatalog();
  }

  Future<void> loadCatalog({bool refresh = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final (products, categories) = await _catalog.load(refresh: refresh);
      _products = products;
      _categories = categories;
    } catch (_) {
      _error = 'Gagal memuat data.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }
}
