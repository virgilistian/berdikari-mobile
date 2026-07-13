import 'json_utils.dart';

/// Daily stock opname line — shape from berdikari-web `app/stores/dailyStock.ts`.
class DailyStockItem {
  const DailyStockItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.openingQty,
    required this.soldQty,
    required this.closingQty,
    required this.status,
  });

  factory DailyStockItem.fromJson(Map<String, dynamic> json) => DailyStockItem(
        id: json['id'].toString(),
        productId: json['product_id'].toString(),
        productName: json['product_name'] as String? ?? '',
        openingQty: (json['opening_qty'] as num?)?.toInt() ?? 0,
        soldQty: (json['sold_qty'] as num?)?.toInt() ?? 0,
        closingQty: (json['closing_qty'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'open',
      );

  final String id;
  final String productId;
  final String productName;
  final int openingQty;
  final int soldQty;
  final int? closingQty;

  /// `open` or `closed`.
  final String status;

  int get remainingQty => (openingQty - soldQty).clamp(0, openingQty);
}

/// A catalog product as seen by the daily-stock opening flow —
/// `GET /inventory/daily-stock/products`.
class ProductForStock {
  const ProductForStock({
    required this.id,
    required this.name,
    required this.price,
    required this.currentStock,
  });

  factory ProductForStock.fromJson(Map<String, dynamic> json) =>
      ProductForStock(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        price: json['price'] == null ? null : parseRupiah(json['price']),
        currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final int? price;
  final int currentStock;
}
