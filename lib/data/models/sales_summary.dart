import 'json_utils.dart';

/// `GET /sales/summary` — aggregated sales for a date range, used by the
/// Reports screen. Shape from berdikari-web `reports/index.vue`.
class SalesSummary {
  const SalesSummary({
    required this.orderCount,
    required this.grossSales,
    required this.paidAmount,
    required this.averageTicket,
    required this.daily,
    required this.topProducts,
    required this.paymentMethods,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
        grossSales: parseRupiah(json['gross_sales']),
        paidAmount: parseRupiah(json['paid_amount']),
        averageTicket: parseRupiah(json['average_ticket']),
        daily: (json['daily'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DailySales.fromJson)
            .toList(),
        topProducts: (json['top_products'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TopProduct.fromJson)
            .toList(),
        paymentMethods: (json['payment_methods'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), parseRupiah(value)),
        ),
      );

  static const empty = SalesSummary(
    orderCount: 0,
    grossSales: 0,
    paidAmount: 0,
    averageTicket: 0,
    daily: [],
    topProducts: [],
    paymentMethods: {},
  );

  final int orderCount;
  final int grossSales;
  final int paidAmount;
  final int averageTicket;
  final List<DailySales> daily;
  final List<TopProduct> topProducts;
  final Map<String, int> paymentMethods;
}

class DailySales {
  const DailySales({required this.date, required this.total, required this.orders});

  factory DailySales.fromJson(Map<String, dynamic> json) => DailySales(
        date: json['date'] as String? ?? '',
        total: parseRupiah(json['total']),
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );

  final String date;
  final int total;
  final int orders;
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.subtotal,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productId: json['product_id'].toString(),
        name: json['name'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        subtotal: parseRupiah(json['subtotal']),
      );

  final String productId;
  final String? name;
  final int quantity;
  final int subtotal;
}
