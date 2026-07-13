import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/product.dart';
import 'auth_repository.dart';
import '../services/client_uuid.dart';
import '../services/sales_service.dart';

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

/// POS cart — mirrors berdikari-web `cart.ts` (offline queue deferred to
/// Phase 6). App-scoped [ChangeNotifier] so the cart survives navigation
/// between tabs during a shift.
class CartRepository extends ChangeNotifier {
  CartRepository({
    required SalesService salesService,
    required AuthRepository authRepository,
  })  : _sales = salesService,
        _auth = authRepository;

  final SalesService _sales;
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

  /// Submits the cart as a completed order. [payment] is the amount
  /// tendered; an empty payments list means pay-later. Clears the cart on
  /// success and returns the receipt-shaped order.
  Future<Order> checkout({
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
      'action': 'complete',
      'customer_name':
          (customerName != null && customerName.isNotEmpty) ? customerName : null,
      'items': [
        for (final item in _items)
          {
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
          },
      ],
      'payments': [
        if (payment != null && payment > 0)
          {'amount': payment, 'method': method},
      ],
    };

    final order = await _sales.submitOrder(payload);
    clear();
    return order;
  }
}
