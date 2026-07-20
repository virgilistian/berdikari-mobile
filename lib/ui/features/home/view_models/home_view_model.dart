import 'package:flutter/foundation.dart';

import '../../../../data/local/app_database.dart';
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
    required AppDatabase database,
  })  : _sales = salesService,
        _finance = financeService,
        _inventory = inventoryService,
        _auth = authRepository,
        _db = database;

  final SalesService _sales;
  final FinanceService _finance;
  final InventoryService _inventory;
  final AuthRepository _auth;
  final AppDatabase _db;

  bool _loadingKpi = true;
  bool _loadingTransactions = true;

  /// True once a cached snapshot has already painted the screen — the
  /// background refresh that follows must stay silent (no spinner flash).
  bool _hasCachedSnapshot = false;
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

  /// Paints instantly from the cached snapshot (if any), then always
  /// refreshes from the network in the background and writes the fresh
  /// result back to the cache — never blocks the UI on the network.
  Future<void> load() async {
    _loadFromCache();
    await Future.wait([_loadKpis(), _loadTransactions()]);
    _writeCache();
  }

  void _loadFromCache() {
    final businessId = _auth.user?.businessId;
    if (businessId == null) return;
    final cached = _db.getDashboardCache(businessId);
    if (cached == null) return;

    _hasCachedSnapshot = true;
    final salesTodayJson = cached['sales_today'] as Map<String, dynamic>?;
    _salesToday = salesTodayJson == null
        ? null
        : SalesToday(
            grossSales: salesTodayJson['gross'] as int,
            orderCount: salesTodayJson['count'] as int,
          );
    _cashNet = cached['cash_net'] as int?;
    _cashIncome = cached['cash_income'] as int?;
    _lowStockCount = cached['low_stock_count'] as int?;
    _recentOrders = (cached['recent_orders'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => Order(
              id: m['id'] as String,
              orderNo: m['order_no'] as String?,
              status: m['status'] as String,
              paymentStatus: m['payment_status'] as String,
              totalAmount: m['total_amount'] as int,
              paidAmount: 0,
              changeAmount: 0,
              balanceDue: 0,
              customerName: m['customer_name'] as String?,
              createdAt: DateTime.parse(m['created_at'] as String),
              items: List.generate(
                m['item_count'] as int? ?? 0,
                (_) => const OrderItem(
                    productId: '', quantity: 0, unitPrice: 0, subtotal: 0),
              ),
              payments: const [],
            ))
        .toList();
    _loadingKpi = false;
    _loadingTransactions = false;
    notifyListeners();
  }

  void _writeCache() {
    final businessId = _auth.user?.businessId;
    if (businessId == null) return;
    _db.putDashboardCache(businessId, {
      'sales_today': _salesToday == null
          ? null
          : {'gross': _salesToday!.grossSales, 'count': _salesToday!.orderCount},
      'cash_net': _cashNet,
      'cash_income': _cashIncome,
      'low_stock_count': _lowStockCount,
      'recent_orders': [
        for (final order in _recentOrders)
          {
            'id': order.id,
            'order_no': order.orderNo,
            'status': order.status,
            'payment_status': order.paymentStatus,
            'total_amount': order.totalAmount,
            'customer_name': order.customerName,
            'created_at': order.createdAt.toIso8601String(),
            'item_count': order.items.length,
          },
      ],
    });
  }

  Future<void> _loadKpis() async {
    if (!_hasCachedSnapshot) _loadingKpi = true;
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
    if (!_hasCachedSnapshot) _loadingTransactions = true;
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
