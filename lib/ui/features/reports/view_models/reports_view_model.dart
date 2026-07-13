import 'package:flutter/foundation.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/models/sales_summary.dart';
import '../../../../data/models/stock.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/finance_service.dart';
import '../../../../data/services/inventory_service.dart';
import '../../../../data/services/sales_service.dart';

/// Plain-language takeaway generated from the aggregates — data only, no
/// copy. The view renders each variant through l10n (mirrors how
/// `orderStatusLabel` keeps copy out of view-models/repositories).
sealed class ReportInsight {}

class TopProductInsight extends ReportInsight {
  TopProductInsight({required this.name, required this.quantity});
  final String name;
  final int quantity;
}

class BestDayInsight extends ReportInsight {
  BestDayInsight({required this.date, required this.total});
  final DateTime date;
  final int total;
}

class ReceivableInsight extends ReportInsight {
  ReceivableInsight({required this.amount});
  final int amount;
}

class NetLossInsight extends ReportInsight {
  NetLossInsight({required this.amount});
  final int amount;
}

class LowStockInsight extends ReportInsight {
  LowStockInsight({required this.count});
  final int count;
}

/// Period presets — same 4 windows as berdikari-web `reports/index.vue`.
enum ReportPeriod { today, days7, days30, days90 }

extension ReportPeriodRange on ReportPeriod {
  int get days => switch (this) {
        ReportPeriod.today => 1,
        ReportPeriod.days7 => 7,
        ReportPeriod.days30 => 30,
        ReportPeriod.days90 => 90,
      };
}

/// Business-wide report: sales + finance + stock aggregates for a period.
/// Mirrors berdikari-web `reports/index.vue`. HR is intentionally out of
/// scope — attendance/leave aren't implemented on mobile yet (Phase 5).
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({
    required SalesService salesService,
    required FinanceService financeService,
    required InventoryService inventoryService,
    required AuthRepository authRepository,
  })  : _salesService = salesService,
        _financeService = financeService,
        _inventoryService = inventoryService,
        _auth = authRepository;

  final SalesService _salesService;
  final FinanceService _financeService;
  final InventoryService _inventoryService;
  final AuthRepository _auth;

  ReportPeriod _period = ReportPeriod.days7;
  bool _loading = true;
  SalesSummary? _sales;
  FinanceSummary? _finance;
  List<StockRow>? _lowStock;

  ReportPeriod get period => _period;
  bool get loading => _loading;
  SalesSummary? get sales => _sales;
  FinanceSummary? get finance => _finance;
  List<StockRow>? get lowStock => _lowStock;

  (DateTime, DateTime) get range {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(Duration(days: _period.days - 1));
    return (from, to);
  }

  static String _iso(DateTime date) => date.toIso8601String().split('T').first;

  List<ReportInsight> get insights {
    final list = <ReportInsight>[];
    final sales = _sales;
    final finance = _finance;
    final lowStock = _lowStock;

    if (sales != null) {
      final topProduct = sales.topProducts.firstOrNull;
      if (topProduct?.name != null) {
        list.add(TopProductInsight(
            name: topProduct!.name!, quantity: topProduct.quantity));
      }
      if (sales.daily.length > 1) {
        final best = [...sales.daily]..sort((a, b) => b.total.compareTo(a.total));
        final bestDay = best.first;
        if (bestDay.total > 0) {
          list.add(BestDayInsight(
              date: DateTime.parse(bestDay.date), total: bestDay.total));
        }
      }
      if (sales.grossSales > sales.paidAmount) {
        list.add(ReceivableInsight(amount: sales.grossSales - sales.paidAmount));
      }
    }
    if (finance != null && finance.net < 0) {
      list.add(NetLossInsight(amount: finance.net.abs()));
    }
    if (lowStock != null && lowStock.isNotEmpty) {
      list.add(LowStockInsight(count: lowStock.length));
    }
    return list;
  }

  Future<void> setPeriod(ReportPeriod period) {
    _period = period;
    return load();
  }

  Future<void> load() async {
    _loading = true;
    final businessId = _auth.user?.businessId;
    final (from, to) = range;
    final fromIso = _iso(from);
    final toIso = _iso(to);

    final jobs = <Future<void>>[
      () async {
        try {
          _sales = await _salesService.fetchSummary(
              businessId: businessId, from: fromIso, to: toIso);
        } catch (_) {
          _sales = null;
        }
      }(),
    ];

    if (_auth.hasPermission('finance.view')) {
      jobs.add(() async {
        try {
          _finance = await _financeService.fetchSummary(
              businessId: businessId, from: fromIso, to: toIso);
        } catch (_) {
          _finance = null;
        }
      }());
    }

    if (_auth.hasPermission('inventory.view')) {
      jobs.add(() async {
        try {
          _lowStock = await _inventoryService.fetchLowStock(businessId: businessId);
        } catch (_) {
          _lowStock = null;
        }
      }());
    }

    await Future.wait(jobs);
    _loading = false;
    notifyListeners();
  }

  /// CSV export — column headers mirror berdikari-web `reports/index.vue`
  /// `exportCsv` verbatim (a data-export artifact, not a translated widget
  /// tree, so it is written directly in Bahasa Indonesia like the web app).
  String buildCsv() {
    final buffer = StringBuffer();
    void row(List<String> cells) => buffer.writeln(cells.map(_csvCell).join(','));

    final sales = _sales;
    if (sales != null) {
      row(['PENJUALAN HARIAN', '', '']);
      row(['Tanggal', 'Total', 'Transaksi']);
      for (final day in sales.daily) {
        row([day.date, '${day.total}', '${day.orders}']);
      }
      row(['', '', '']);
      row(['PRODUK TERLARIS', '', '']);
      row(['Produk', 'Jumlah', 'Subtotal']);
      for (final product in sales.topProducts) {
        row([product.name ?? '-', '${product.quantity}', '${product.subtotal}']);
      }
      row(['', '', '']);
    }

    final finance = _finance;
    if (finance != null) {
      row(['KEUANGAN', '', '']);
      row(['Total Pemasukan', '${finance.totalIncome}', '']);
      row(['Total Pengeluaran', '${finance.totalExpense}', '']);
      row(['Selisih (Laba/Rugi Kas)', '${finance.net}', '']);
    }

    return buffer.toString();
  }

  static String _csvCell(String value) => value.contains(',') || value.contains('"')
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}
