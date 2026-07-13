import 'json_utils.dart';

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
    required this.totalSales,
    required this.closingNote,
    required this.openedAt,
    required this.closedAt,
    required this.cashierName,
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
        totalSales: parseRupiah(json['total_sales']),
        closingNote: json['closing_note'] as String?,
        openedAt: parseDate(json['opened_at']) ?? DateTime.now(),
        closedAt: parseDate(json['closed_at']),
        cashierName:
            (json['cashier'] as Map<String, dynamic>?)?['name'] as String?,
      );

  final String id;

  /// `open` or `closed`.
  final String status;
  final int openingCash;
  final int? closingCash;
  final int? expectedCash;
  final int? cashDifference;
  final int transactionCount;
  final int totalSales;
  final String? closingNote;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? cashierName;

  bool get isOpen => status == 'open';
}
