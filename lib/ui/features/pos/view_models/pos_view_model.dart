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
  bool _loading = true;
  String? _error;

  List<ProductCategory> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get loading => _loading;
  String? get error => _error;

  List<Product> get visibleProducts => _selectedCategoryId == null
      ? _products
      : _products
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();

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
