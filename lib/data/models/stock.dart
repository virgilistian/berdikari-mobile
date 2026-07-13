import 'json_utils.dart';

/// One product's stock & valuation row — shape from berdikari-web
/// `app/stores/inventory.ts`.
class StockRow {
  const StockRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.minStock,
    required this.purchasePrice,
    required this.stockValue,
    required this.isLow,
  });

  factory StockRow.fromJson(Map<String, dynamic> json) => StockRow(
        productId: json['product_id'].toString(),
        productName: json['product_name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
        purchasePrice: parseRupiah(json['purchase_price']),
        stockValue: parseRupiah(json['stock_value']),
        isLow: json['is_low'] as bool? ?? false,
      );

  final String productId;
  final String productName;
  final int quantity;
  final int minStock;
  final int purchasePrice;
  final int stockValue;
  final bool isLow;
}

class StockSummary {
  const StockSummary({
    required this.totalProducts,
    required this.stockValue,
    required this.retailValue,
    required this.lowStockCount,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) => StockSummary(
        totalProducts: (json['total_products'] as num?)?.toInt() ?? 0,
        stockValue: parseRupiah(json['stock_value']),
        retailValue: parseRupiah(json['retail_value']),
        lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      );

  final int totalProducts;
  final int stockValue;
  final int retailValue;
  final int lowStockCount;
}

/// One stock movement ledger entry — `GET /inventory/{id}/movements`.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'].toString(),
        type: json['type'] as String? ?? 'adjustment',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String?,
        createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      );

  final String id;

  /// `in`, `out`, or `adjustment`.
  final String type;
  final int quantity;
  final String? reason;
  final DateTime createdAt;
}
