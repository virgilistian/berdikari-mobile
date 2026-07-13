import 'package:flutter/foundation.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/services/api_client.dart';

/// State for the product create/edit form. Mirrors berdikari-web's
/// `ProductForm` submit/delete/createCategory flow in `catalog/index.vue`.
class ProductFormViewModel extends ChangeNotifier {
  ProductFormViewModel({
    required CatalogRepository catalogRepository,
    Product? existing,
  })  : _catalog = catalogRepository,
        editing = existing;

  final CatalogRepository _catalog;

  /// Null when creating a new product.
  final Product? editing;

  bool _saving = false;
  bool _savingCategory = false;
  String? _errorMessage;

  bool get saving => _saving;
  bool get savingCategory => _savingCategory;
  String? get errorMessage => _errorMessage;

  Future<Product?> submit({
    required String name,
    required String? categoryId,
    required int price,
    required int costPrice,
    required bool isActive,
  }) async {
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _catalog.saveProduct(
        id: editing?.id,
        name: name,
        categoryId: categoryId,
        price: price,
        costPrice: costPrice,
        isActive: isActive,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete() async {
    final id = editing?.id;
    if (id == null) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _catalog.deleteProduct(id);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<ProductCategory?> createCategory(String name) async {
    _savingCategory = true;
    notifyListeners();
    try {
      return await _catalog.createCategory(name);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } finally {
      _savingCategory = false;
      notifyListeners();
    }
  }
}
