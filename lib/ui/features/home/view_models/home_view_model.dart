import 'package:flutter/foundation.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/finance_service.dart';
import '../../../../data/services/inventory_service.dart';
import '../../../../data/services/sales_service.dart';

/// The one highlighted quick action — depends on the user's main
/// responsibility. Mirrors berdikari-web `index.vue` `primaryAction`.
enum PrimaryAction { openShift, addFinanceEntry, openDailyStock }

/// Today's sales totals (pos.view only). Null fields render as missing
/// KPI cards, e.g. after a permission gate or a failed fetch.
class SalesToday {
  const SalesToday({required this.grossSales, required this.orderCount});
  final int grossSales;
  final int orderCount;
  int get averageTicket => orderCount == 0 ? 0 : grossSales ~/ orderCount;
}

/// Composes today's KPIs + recent transactions for the dashboard.
/// Read-only aggregation across Sales/Finance/Inventory — mirrors
/// berdikari-web `pages/index.vue`. Deliberately does not reuse
/// `FinanceRepository`/`StockRepository`: those hold page-specific filter
/// state (finance period/type, full stock list) that dashboard KPIs must
/// not depend on. Labels/copy live in the view (l10n), not here.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required SalesService salesService,
    required FinanceService financeService,
    required InventoryService inventoryService,
    required AuthRepository authRepository,
  })  : _sales = salesService,
        _finance = financeService,
        _inventory = inventoryService,
        _auth = authRepository;

  final SalesService _sales;
  final FinanceService _finance;
  final InventoryService _inventory;
  final AuthRepository _auth;

  bool _loadingKpi = true;
  bool _loadingTransactions = true;
  SalesToday? _salesToday;
  int? _cashNet;
  int? _cashIncome;
  int? _lowStockCount;
  List<Order> _recentOrders = [];

  bool get loadingKpi => _loadingKpi;
  bool get loadingTransactions => _loadingTransactions;
  SalesToday? get salesToday => _salesToday;
  int? get cashNet => _cashNet;
  int? get cashIncome => _cashIncome;
  int? get lowStockCount => _lowStockCount;
  List<Order> get recentOrders => _recentOrders;

  PrimaryAction? get primaryAction {
    if (_auth.hasPermission('pos.open')) return PrimaryAction.openShift;
    if (_auth.hasPermission('finance.create')) return PrimaryAction.addFinanceEntry;
    if (_auth.hasPermission('inventory.create')) return PrimaryAction.openDailyStock;
    return null;
  }

  Future<void> load() => Future.wait([_loadKpis(), _loadTransactions()]);

  Future<void> _loadKpis() async {
    _loadingKpi = true;
    final businessId = _auth.user?.businessId;
    final today = DateTime.now().toIso8601String().split('T').first;

    final jobs = <Future<void>>[];

    if (_auth.hasPermission('pos.view')) {
      jobs.add(() async {
        try {
          final orders = await _sales.fetchOrders(
            businessId: businessId,
            date: today,
            status: 'completed',
          );
          _salesToday = SalesToday(
            grossSales: orders.fold<int>(0, (sum, o) => sum + o.totalAmount),
            orderCount: orders.length,
          );
        } catch (_) {
          _salesToday = null;
        }
      }());
    }

    if (_auth.hasPermission('finance.view')) {
      jobs.add(() async {
        try {
          final summary = await _finance.fetchSummary(businessId: businessId);
          _cashNet = summary.net;
          _cashIncome = summary.totalIncome;
        } catch (_) {
          _cashNet = null;
          _cashIncome = null;
        }
      }());
    }

    if (_auth.hasPermission('inventory.view')) {
      jobs.add(() async {
        try {
          final lowStock = await _inventory.fetchLowStock(businessId: businessId);
          _lowStockCount = lowStock.length;
        } catch (_) {
          _lowStockCount = null;
        }
      }());
    }

    await Future.wait(jobs);
    _loadingKpi = false;
    notifyListeners();
  }

  Future<void> _loadTransactions() async {
    if (!_auth.hasPermission('pos.view')) {
      _loadingTransactions = false;
      notifyListeners();
      return;
    }
    _loadingTransactions = true;
    try {
      final orders = await _sales.fetchOrders(businessId: _auth.user?.businessId);
      _recentOrders = orders.take(5).toList();
    } catch (_) {
      _recentOrders = [];
    } finally {
      _loadingTransactions = false;
      notifyListeners();
    }
  }
}
