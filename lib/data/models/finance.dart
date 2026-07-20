import 'json_utils.dart';

/// Expense/income category options — mirrors berdikari-web `finance.ts`
/// `EXPENSE_CATEGORIES` / `INCOME_CATEGORIES` (plain UMKM words, no
/// accounting jargon; DNA §2).
const List<String> kExpenseCategories = [
  'Belanja Bahan',
  'Bayar Listrik',
  'Bayar Air',
  'Gaji Karyawan',
  'Perbaikan',
  'Transportasi',
  'BBM',
  'Sewa',
  'Perlengkapan',
  'Lainnya',
];

const List<String> kIncomeCategories = [
  'Penjualan',
  'Jasa',
  'Pembayaran Piutang',
  'Investasi',
  'Hibah',
  'Lainnya',
];

/// One cash flow entry (pemasukan/pengeluaran) — `GET/POST /finance`.
class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.occurredAt,
    this.businessId,
    this.businessName,
    this.sourceType,
    this.sourceId,
    this.pendingSync = false,
  });

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
        id: json['id'].toString(),
        type: json['type'] as String? ?? 'expense',
        amount: parseRupiah(json['amount']),
        category: json['category'] as String? ?? '',
        note: json['note'] as String?,
        occurredAt: parseDate(json['occurred_at']) ?? DateTime.now(),
        businessId: json['business_id'] as String?,
        businessName: json['business_name'] as String?,
        sourceType: json['source_type'] as String?,
        sourceId: json['source_id'] as String?,
      );

  final String id;

  /// `income` or `expense`.
  final String type;
  final int amount;
  final String category;
  final String? note;
  final DateTime occurredAt;
  final String? businessId;
  final String? businessName;

  /// `manual` (or null) for cashier-entered rows; anything else (e.g.
  /// `sale_order`, `sale_order_refund`) means the API generated this entry
  /// automatically and will refuse to delete it.
  final String? sourceType;
  final String? sourceId;

  /// True while a create/delete for this entry is still sitting in the
  /// local sync outbox, not yet confirmed by the server.
  final bool pendingSync;

  bool get isIncome => type == 'income';

  /// True for entries the API generated automatically (from a POS sale) —
  /// `DELETE /finance/{id}` rejects these with a 422, so the UI should
  /// never offer a delete action for them.
  bool get isAuto => sourceType != null && sourceType != 'manual';
}

/// `GET /finance/summary` — totals + per-category breakdown for a range.
class FinanceSummary {
  const FinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) =>
      FinanceSummary(
        totalIncome: parseRupiah(json['total_income']),
        totalExpense: parseRupiah(json['total_expense']),
        net: parseRupiah(json['net']),
        incomeByCategory: _parseCategoryMap(json['income_by_category']),
        expenseByCategory: _parseCategoryMap(json['expense_by_category']),
      );

  static const empty = FinanceSummary(
    totalIncome: 0,
    totalExpense: 0,
    net: 0,
    incomeByCategory: {},
    expenseByCategory: {},
  );

  final int totalIncome;
  final int totalExpense;
  final int net;
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByCategory;

  static Map<String, int> _parseCategoryMap(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): parseRupiah(entry.value),
    };
  }
}
