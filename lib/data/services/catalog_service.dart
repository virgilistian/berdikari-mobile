import '../models/product.dart';
import 'api_client.dart';

/// Catalog module endpoints (`/v1/catalog/*`).
class CatalogService {
  CatalogService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<Product>> fetchProducts() async {
    final response = await _api.get('/catalog/products');
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }

  Future<List<ProductCategory>> fetchCategories() async {
    final response = await _api.get('/catalog/categories');
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductCategory.fromJson)
        .toList();
  }

  /// `id` present -> `PUT` (update); absent -> `POST` (create).
  Future<Product> saveProduct({
    String? id,
    required String name,
    required String? categoryId,
    required int price,
    required int costPrice,
    String? sku,
    required bool isActive,
  }) async {
    final body = {
      'name': name,
      'category_id': categoryId,
      'price': price,
      'cost_price': costPrice,
      'sku': sku,
      'is_active': isActive,
    };
    final response = id == null
        ? await _api.post('/catalog/products', body: body)
        : await _api.put('/catalog/products/$id', body: body);
    return Product.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String id) => _api.delete('/catalog/products/$id');

  Future<ProductCategory> createCategory(String name) async {
    final response =
        await _api.post('/catalog/categories', body: {'name': name});
    return ProductCategory.fromJson(response['data'] as Map<String, dynamic>);
  }
}
