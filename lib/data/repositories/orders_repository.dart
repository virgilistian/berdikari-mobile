import '../models/order.dart';
import '../services/sales_service.dart';
import 'auth_repository.dart';

/// Order history + lifecycle actions — mirrors berdikari-web `orders.ts`.
/// These actions target orders that already exist on the server, so
/// (unlike checkout) they are NOT offline-queued — they require
/// connectivity, same as the rest of this read-heavy screen.
class OrdersRepository {
  OrdersRepository({
    required SalesService salesService,
    required AuthRepository authRepository,
  })  : _sales = salesService,
        _auth = authRepository;

  final SalesService _sales;
  final AuthRepository _auth;

  Future<List<Order>> fetchOrders({String? status}) => _sales.fetchOrders(
        businessId: _auth.user?.businessId,
        status: status,
      );

  /// Finishes a held order. [payment] > 0 settles it at the same time
  /// (empty payments = still pay-later after completing).
  Future<Order> complete(String id, {int payment = 0}) => _sales.completeOrder(
        id,
        payments: payment > 0 ? [{'amount': payment, 'method': 'cash'}] : null,
      );

  /// Settles (part of) the balance on a completed-but-unpaid/partial order.
  Future<Order> pay(String id, int amount) =>
      _sales.payOrder(id, amount: amount);

  Future<Order> cancel(String id) => _sales.cancelOrder(id);

  Future<Order> refund(String id) => _sales.refundOrder(id);
}
