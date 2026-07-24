import 'package:flutter/foundation.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../../data/services/api_client.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({required OrdersRepository ordersRepository})
      : _orders = ordersRepository;

  final OrdersRepository _orders;

  List<Order> _items = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;
  String? _actionError;

  /// Empty string = all statuses. `'unpaid'` is a derived filter (not a
  /// real order status): fetches `completed` orders, then keeps only those
  /// with an outstanding balance — mirrors berdikari-web `orders.vue`'s
  /// "Belum Lunas" tab.
  String _statusFilter = '';

  List<Order> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  bool get busy => _busy;
  String? get actionError => _actionError;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final isUnpaid = _statusFilter == 'unpaid';
      _items = await _orders.fetchOrders(
        status: isUnpaid
            ? 'completed'
            : (_statusFilter.isEmpty ? null : _statusFilter),
      );
      if (isUnpaid) {
        _items = _items.where((o) => o.balanceDue > 0).toList();
      }
    } catch (_) {
      _error = 'Gagal memuat data.';
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setStatusFilter(String status) {
    _statusFilter = status;
    return load();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<Order?> _run(Future<Order> Function() action) async {
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      final updated = await action();
      await load();
      return updated;
    } on ApiException catch (e) {
      _actionError = e.message;
      return null;
    } catch (_) {
      _actionError = 'Terjadi kesalahan. Silakan coba lagi.';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Order?> complete(String id, {int payment = 0}) =>
      _run(() => _orders.complete(id, payment: payment));

  Future<Order?> pay(String id, int amount) =>
      _run(() => _orders.pay(id, amount));

  Future<Order?> cancel(String id) => _run(() => _orders.cancel(id));

  Future<Order?> refund(String id) => _run(() => _orders.refund(id));
}
