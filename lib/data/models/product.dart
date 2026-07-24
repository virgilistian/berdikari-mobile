import 'json_utils.dart';

/// Catalog product — shape from berdikari-web `app/stores/catalog.ts`.
class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.sku,
    required this.price,
    required this.costPrice,
    required this.isActive,
    required this.imageUrl,
    this.hasPhoto = false,
    this.pendingImagePath,
    this.pendingSync = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'].toString(),
        categoryId: json['category_id']?.toString(),
        categoryName:
            (json['category'] as Map<String, dynamic>?)?['name'] as String?,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        price: parseRupiah(json['price']),
        costPrice: parseRupiah(json['cost_price']),
        isActive: json['is_active'] as bool? ?? true,
        imageUrl: json['image_url'] as String?,
        hasPhoto: json['has_photo'] as bool? ?? false,
      );

  final String id;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? sku;

  /// Selling price in whole Rupiah.
  final int price;

  /// HPP (modal) — production cost per unit, in whole Rupiah.
  final int costPrice;
  final bool isActive;
  final String? imageUrl;

  /// True once the server holds a compressed photo for this product,
  /// reachable at `GET /catalog/products/{id}/image`.
  final bool hasPhoto;

  /// Local-only: path to a compressed photo file waiting to be uploaded
  /// (queued because the product hadn't synced yet, or the device was
  /// offline when it was picked). Never sent to the server directly —
  /// [CatalogRepository] uploads it via a dedicated multipart request once
  /// a real product id and connectivity are both available.
  final String? pendingImagePath;

  /// True while a create/update for this product is still sitting in the
  /// local sync outbox, not yet confirmed by the server.
  final bool pendingSync;

  Product copyWith({
    bool? hasPhoto,
    String? pendingImagePath,
    bool clearPendingImagePath = false,
  }) =>
      Product(
        id: id,
        categoryId: categoryId,
        categoryName: categoryName,
        name: name,
        sku: sku,
        price: price,
        costPrice: costPrice,
        isActive: isActive,
        imageUrl: imageUrl,
        hasPhoto: hasPhoto ?? this.hasPhoto,
        pendingImagePath: clearPendingImagePath
            ? null
            : (pendingImagePath ?? this.pendingImagePath),
        pendingSync: pendingSync,
      );
}

class ProductCategory {
  const ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
      );

  final String id;
  final String name;
}
