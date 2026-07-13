import 'json_utils.dart';

/// Catalog product — shape from berdikari-web `app/stores/catalog.ts`.
class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.sku,
    required this.price,
    required this.isActive,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'].toString(),
        categoryId: json['category_id']?.toString(),
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        price: parseRupiah(json['price']),
        isActive: json['is_active'] as bool? ?? true,
        imageUrl: json['image_url'] as String?,
      );

  final String id;
  final String? categoryId;
  final String name;
  final String? sku;

  /// Selling price in whole Rupiah.
  final int price;
  final bool isActive;
  final String? imageUrl;
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
