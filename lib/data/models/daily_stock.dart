import 'json_utils.dart';

/// Daily stock opname line — shape from berdikari-web `app/stores/dailyStock.ts`.
class DailyStockItem {
  const DailyStockItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.openingQty,
    required this.adjustmentQty,
    required this.adjustmentNote,
    required this.soldQty,
    required this.closingQty,
    required this.status,
    this.currentStock,
    this.remainingQtyFromApi,
  });

  factory DailyStockItem.fromJson(Map<String, dynamic> json) => DailyStockItem(
        id: json['id'].toString(),
        productId: json['product_id'].toString(),
        productName: json['product_name'] as String? ?? '',
        price: json['price'] == null ? null : parseRupiah(json['price']),
        imageUrl: json['image_url'] as String?,
        openingQty: (json['opening_qty'] as num?)?.toInt() ?? 0,
        adjustmentQty: (json['adjustment_qty'] as num?)?.toInt() ?? 0,
        adjustmentNote: json['adjustment_note'] as String?,
        soldQty: (json['sold_qty'] as num?)?.toInt() ?? 0,
        closingQty: (json['closing_qty'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'open',
        currentStock: (json['current_stock'] as num?)?.toInt(),
        remainingQtyFromApi: (json['remaining_qty'] as num?)?.toInt(),
      );

  final String id;
  final String productId;
  final String productName;
  final int? price;
  final String? imageUrl;
  final int openingQty;
  final int adjustmentQty;
  final String? adjustmentNote;
  final int soldQty;
  final int? closingQty;
  final int? currentStock;
  final int? remainingQtyFromApi;

  /// `draft` (future-dated, not live yet), `open` (today, live) or `closed`.
  final String status;

  bool get isDraft => status == 'draft';
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  /// Prefers the API-computed value (accounts for adjustments); falls back
  /// to a local calc — mirrors berdikari-web `shift.vue`'s `systemRemaining`.
  int get remainingQty =>
      remainingQtyFromApi ??
      (openingQty + adjustmentQty - soldQty).clamp(0, 1 << 31);
}

/// A catalog product as seen by the daily-stock opening flow —
/// `GET /inventory/daily-stock/products`.
class ProductForStock {
  const ProductForStock({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.currentStock,
    required this.minStock,
  });

  factory ProductForStock.fromJson(Map<String, dynamic> json) =>
      ProductForStock(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        price: json['price'] == null ? null : parseRupiah(json['price']),
        imageUrl: json['image_url'] as String?,
        currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
        minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final int? price;
  final String? imageUrl;
  final int currentStock;
  final int minStock;
}

/// One row of `GET /inventory/daily-stock/history` — a per-date summary.
class DailyStockHistoryRow {
  const DailyStockHistoryRow({
    required this.date,
    required this.totalMenuItems,
    required this.totalOpeningQty,
    required this.totalClosingQty,
    required this.status,
  });

  factory DailyStockHistoryRow.fromJson(Map<String, dynamic> json) =>
      DailyStockHistoryRow(
        date: json['date'] as String? ?? '',
        totalMenuItems: (json['total_menu_items'] as num?)?.toInt() ?? 0,
        totalOpeningQty: (json['total_opening_qty'] as num?)?.toInt() ?? 0,
        totalClosingQty: (json['total_closing_qty'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'closed',
      );

  final String date;
  final int totalMenuItems;
  final int totalOpeningQty;
  final int totalClosingQty;

  /// `draft`, `open` or `closed`.
  final String status;
}
