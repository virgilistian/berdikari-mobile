import 'package:flutter/foundation.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/catalog_repository.dart';

/// State for the Katalog Produk screen: search + category filter over
/// every product (including inactive ones — this is the management view,
/// unlike the POS grid which only shows active products for sale).
class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required CatalogRepository catalogRepository})
      : _catalog = catalogRepository;

  final CatalogRepository _catalog;

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _loading = true;

  List<Product> get products => _products;
  List<ProductCategory> get categories => _categories;
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get loading => _loading;

  List<Product> get filteredProducts {
    var list = _selectedCategoryId == null
        ? _products
        : _products.where((p) => p.categoryId == _selectedCategoryId).toList();
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(query)).toList();
    }
    return list;
  }

  Future<void> load({bool refresh = false}) async {
    _loading = true;
    notifyListeners();
    final (products, categories) = await _catalog.loadAll(refresh: refresh);
    _products = products;
    _categories = categories;
    _loading = false;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    notifyListeners();
  }
}
