import '../models/product.dart';
import '../services/catalog_service.dart';

/// Products + categories, cached per app session.
///
/// [load] returns active-only products (for the POS grid); [loadAll]
/// returns every product including inactive ones (for the Catalog
/// management screen, which needs to toggle/edit them).
class CatalogRepository {
  CatalogRepository({required CatalogService catalogService})
      : _catalog = catalogService;

  final CatalogService _catalog;

  List<Product>? _products;
  List<ProductCategory>? _categories;

  Future<void> _ensureLoaded({bool refresh = false}) async {
    if (refresh || _products == null || _categories == null) {
      final results = await Future.wait([
        _catalog.fetchProducts(),
        _catalog.fetchCategories(),
      ]);
      _products = results[0] as List<Product>;
      _categories = results[1] as List<ProductCategory>;
    }
  }

  Future<(List<Product>, List<ProductCategory>)> load(
      {bool refresh = false}) async {
    await _ensureLoaded(refresh: refresh);
    return (_products!.where((p) => p.isActive).toList(), _categories!);
  }

  Future<(List<Product>, List<ProductCategory>)> loadAll(
      {bool refresh = false}) async {
    await _ensureLoaded(refresh: refresh);
    return (_products!, _categories!);
  }

  Future<Product> saveProduct({
    String? id,
    required String name,
    required String? categoryId,
    required int price,
    required int costPrice,
    String? sku,
    required bool isActive,
  }) async {
    final product = await _catalog.saveProduct(
      id: id,
      name: name,
      categoryId: categoryId,
      price: price,
      costPrice: costPrice,
      sku: sku,
      isActive: isActive,
    );
    await _ensureLoaded(refresh: true);
    return product;
  }

  Future<void> deleteProduct(String id) async {
    await _catalog.deleteProduct(id);
    await _ensureLoaded(refresh: true);
  }

  Future<ProductCategory> createCategory(String name) async {
    final category = await _catalog.createCategory(name);
    _categories = [...?_categories, category];
    return category;
  }
}
