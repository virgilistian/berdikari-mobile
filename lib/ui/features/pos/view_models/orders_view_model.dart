import 'package:flutter/foundation.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/orders_repository.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({required OrdersRepository ordersRepository})
      : _orders = ordersRepository;

  final OrdersRepository _orders;

  List<Order> _items = [];
  bool _loading = true;
  String? _error;

  /// Empty string = all statuses.
  String _statusFilter = '';

  List<Order> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String get statusFilter => _statusFilter;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _orders.fetchOrders(
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
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
}
