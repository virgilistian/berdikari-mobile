import 'json_utils.dart';

/// One product line in a closed shift's stock reconciliation snapshot —
/// shape from berdikari-web `app/stores/shift.ts` `ShiftStockSummaryItem`.
class ShiftStockSummaryItem {
  const ShiftStockSummaryItem({
    required this.productId,
    required this.productName,
    required this.openingQty,
    required this.soldQty,
    required this.adjustmentQty,
    required this.adjustmentNote,
    required this.closingQty,
  });

  factory ShiftStockSummaryItem.fromJson(Map<String, dynamic> json) =>
      ShiftStockSummaryItem(
        productId: json['product_id'].toString(),
        productName: json['product_name'] as String? ?? '',
        openingQty: (json['opening_qty'] as num?)?.toInt() ?? 0,
        soldQty: (json['sold_qty'] as num?)?.toInt() ?? 0,
        adjustmentQty: (json['adjustment_qty'] as num?)?.toInt() ?? 0,
        adjustmentNote: json['adjustment_note'] as String?,
        closingQty: (json['closing_qty'] as num?)?.toInt() ?? 0,
      );

  final String productId;
  final String productName;
  final int openingQty;
  final int soldQty;
  final int adjustmentQty;
  final String? adjustmentNote;
  final int closingQty;
}

/// Cashier shift — shape from berdikari-web `app/stores/shift.ts`.
class CashierShift {
  const CashierShift({
    required this.id,
    required this.status,
    required this.openingCash,
    required this.closingCash,
    required this.expectedCash,
    required this.cashDifference,
    required this.transactionCount,
    required this.totalItemsSold,
    required this.totalSales,
    required this.totalExpenses,
    required this.netIncome,
    required this.closingNote,
    required this.openedAt,
    required this.closedAt,
    required this.cashierName,
    this.paymentBreakdown = const {},
    this.stockSummary = const [],
  });

  factory CashierShift.fromJson(Map<String, dynamic> json) => CashierShift(
        id: json['id'].toString(),
        status: json['status'] as String? ?? 'open',
        openingCash: parseRupiah(json['opening_cash']),
        closingCash:
            json['closing_cash'] == null ? null : parseRupiah(json['closing_cash']),
        expectedCash: json['expected_cash'] == null
            ? null
            : parseRupiah(json['expected_cash']),
        cashDifference: json['cash_difference'] == null
            ? null
            : parseRupiah(json['cash_difference']),
        transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
        totalItemsSold: (json['total_items_sold'] as num?)?.toInt() ?? 0,
        totalSales: parseRupiah(json['total_sales']),
        totalExpenses: parseRupiah(json['total_expenses']),
        netIncome: json['net_income'] == null ? null : parseRupiah(json['net_income']),
        closingNote: json['closing_note'] as String?,
        openedAt: parseDate(json['opened_at']) ?? DateTime.now(),
        closedAt: parseDate(json['closed_at']),
        cashierName:
            (json['cashier'] as Map<String, dynamic>?)?['name'] as String?,
        paymentBreakdown: _parseBreakdown(json['payment_breakdown']),
        stockSummary: (json['stock_summary'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ShiftStockSummaryItem.fromJson)
            .toList(),
      );

  static Map<String, int> _parseBreakdown(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): parseRupiah(entry.value),
    };
  }

  final String id;

  /// `open` or `closed`.
  final String status;
  final int openingCash;
  final int? closingCash;
  final int? expectedCash;
  final int? cashDifference;
  final int transactionCount;
  final int totalItemsSold;
  final int totalSales;
  final int totalExpenses;
  final int? netIncome;
  final String? closingNote;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? cashierName;

  /// Payment method -> amount, e.g. `{cash: 50000, qris: 20000}`. Present
  /// on the active shift (live) and on closed shifts (final).
  final Map<String, int> paymentBreakdown;

  /// Stock reconciliation snapshot taken when the shift closed (empty
  /// while the shift is still open).
  final List<ShiftStockSummaryItem> stockSummary;

  bool get isOpen => status == 'open';

  int get cashSales => paymentBreakdown['cash'] ?? 0;
  int get nonCashSales => totalSales - cashSales;

  /// `opening_cash + cash sales - operational expenses` — the live
  /// "expected cash" preview shown while the cashier types the closing
  /// amount, mirrors berdikari-web `shift.vue`'s `expectedCashLive` computed.
  int expectedCashLive() => openingCash + cashSales - totalExpenses;
}
