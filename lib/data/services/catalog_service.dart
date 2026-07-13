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
}
