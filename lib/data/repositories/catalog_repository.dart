import '../models/product.dart';
import '../services/catalog_service.dart';

/// Products + categories for the POS grid, cached per app session.
class CatalogRepository {
  CatalogRepository({required CatalogService catalogService})
      : _catalog = catalogService;

  final CatalogService _catalog;

  List<Product>? _products;
  List<ProductCategory>? _categories;

  Future<(List<Product>, List<ProductCategory>)> load({bool refresh = false}) async {
    if (refresh || _products == null || _categories == null) {
      final results = await Future.wait([
        _catalog.fetchProducts(),
        _catalog.fetchCategories(),
      ]);
      _products = (results[0] as List<Product>)
          .where((p) => p.isActive)
          .toList();
      _categories = results[1] as List<ProductCategory>;
    }
    return (_products!, _categories!);
  }
}
