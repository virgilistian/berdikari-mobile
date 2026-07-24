import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/device_image_service.dart';

/// State for the product create/edit form. Mirrors berdikari-web's
/// `ProductForm` submit/delete/createCategory flow in `catalog/index.vue`.
class ProductFormViewModel extends ChangeNotifier {
  ProductFormViewModel({
    required CatalogRepository catalogRepository,
    required DeviceImageService deviceImageService,
    Product? existing,
  })  : _catalog = catalogRepository,
        _deviceImage = deviceImageService,
        editing = existing,
        _hasPhoto = existing?.hasPhoto ?? false;

  final CatalogRepository _catalog;
  final DeviceImageService _deviceImage;

  /// Null when creating a new product.
  final Product? editing;

  bool _saving = false;
  bool _savingCategory = false;
  bool _pickingImage = false;
  String? _errorMessage;

  /// A freshly picked (already client-compressed) photo waiting to be
  /// attached once the product itself is saved. Takes preview priority over
  /// [editing]'s existing server photo.
  File? _pickedImageFile;
  bool _hasPhoto;

  bool get saving => _saving;
  bool get savingCategory => _savingCategory;
  bool get pickingImage => _pickingImage;
  String? get errorMessage => _errorMessage;
  File? get pickedImageFile => _pickedImageFile;

  /// True if a photo should be shown for this product — either one already
  /// saved on the server, or one just picked and not yet uploaded.
  bool get hasPhoto => _hasPhoto;

  Future<void> pickImageFromCamera() => _pickImage(_deviceImage.pickFromCamera);

  Future<void> pickImageFromGallery() => _pickImage(_deviceImage.pickFromGallery);

  Future<void> _pickImage(Future<File?> Function() pick) async {
    _pickingImage = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final file = await pick();
      if (file != null) {
        _pickedImageFile = file;
        _hasPhoto = true;
      }
    } catch (_) {
      _errorMessage = 'Tidak bisa mengambil foto. Coba lagi.';
    } finally {
      _pickingImage = false;
      notifyListeners();
    }
  }

  /// Always means "no photo" — clears a pending local pick and, if the
  /// product already has a saved photo, deletes it immediately.
  Future<void> removeImage() async {
    _pickedImageFile = null;
    final id = editing?.id;
    if (id == null || !(editing?.hasPhoto ?? false)) {
      _hasPhoto = false;
      notifyListeners();
      return;
    }
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _catalog.removeProductImage(id);
      _hasPhoto = false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

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
      final product = await _catalog.saveProduct(
        id: editing?.id,
        name: name,
        categoryId: categoryId,
        price: price,
        costPrice: costPrice,
        isActive: isActive,
      );
      final photo = _pickedImageFile;
      if (photo != null) {
        await _catalog.attachLocalImage(product.id, photo.path);
      }
      return product;
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
