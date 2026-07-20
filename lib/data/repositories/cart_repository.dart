import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/product.dart';
import 'auth_repository.dart';
import 'offline_queue_repository.dart';
import '../services/client_uuid.dart';

/// One line in the POS cart. Quantities are managed by [CartRepository].
class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final int unitPrice;
  int quantity;

  int get subtotal => unitPrice * quantity;
}

/// POS cart — mirrors berdikari-web `cart.ts`. Unlike web (which tries the
/// server first and only queues on failure), every checkout here is
/// offline-first: it's written to [OfflineQueueRepository] immediately and
/// synced in the background, per product decision.
/// App-scoped [ChangeNotifier] so the cart survives navigation between
/// tabs during a shift.
class CartRepository extends ChangeNotifier {
  CartRepository({
    required OfflineQueueRepository offlineQueue,
    required AuthRepository authRepository,
  })  : _offlineQueue = offlineQueue,
        _auth = authRepository;

  final OfflineQueueRepository _offlineQueue;
  final AuthRepository _auth;

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get totalAmount => _items.fold(0, (sum, i) => sum + i.subtotal);
  int get totalItems => _items.fold(0, (sum, i) => sum + i.quantity);

  void addProduct(Product product) {
    final existing =
        _items.where((i) => i.productId == product.id).firstOrNull;
    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(CartItem(
        productId: product.id,
        name: product.name,
        unitPrice: product.price,
        quantity: 1,
      ));
    }
    notifyListeners();
  }

  void increase(String productId) {
    final item = _items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;
    item.quantity++;
    notifyListeners();
  }

  /// Decrementing below 1 removes the line — same behavior as the web cart.
  void decrease(String productId) {
    final item = _items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Enqueues the cart for checkout — always offline-first (see class doc).
  /// [action] is `complete` (paid or pay-later, depending on [payment]) or
  /// `hold` (Simpan). Clears the cart immediately and returns a
  /// receipt-shaped [Order] synthesized from the queued payload, so the UI
  /// never waits on the network.
  Future<Order> submit({
    required String action,
    int? payment,
    String method = 'cash',
    String? customerName,
  }) async {
    if (_items.isEmpty) {
      throw StateError('Keranjang kosong');
    }
    final payload = {
      'business_id': _auth.user?.businessId,
      'client_uuid': generateClientUuid(),
      'action': action,
      'customer_name':
          (customerName != null && customerName.isNotEmpty) ? customerName : null,
      'items': [
        for (final item in _items)
          {
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'name': item.name,
          },
      ],
      'payments': [
        if (payment != null && payment > 0)
          {'amount': payment, 'method': method},
      ],
    };

    final pending = await _offlineQueue.enqueue(payload, totalAmount);
    clear();
    return Order.fromPending(pending);
  }

  /// "Bayar Sekarang" — pays [payment] now (or leaves it unpaid if 0/null,
  /// i.e. "Bayar Nanti" when called with no payment).
  Future<Order> checkout({
    int? payment,
    String method = 'cash',
    String? customerName,
  }) =>
      submit(
        action: 'complete',
        payment: payment,
        method: method,
        customerName: customerName,
      );

  /// "Simpan" — holds the order without deducting stock or requiring
  /// payment; finished later from the Orders screen.
  Future<Order> hold({String? customerName}) =>
      submit(action: 'hold', customerName: customerName);
}
