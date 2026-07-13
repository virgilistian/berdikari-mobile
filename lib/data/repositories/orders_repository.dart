import '../models/order.dart';
import '../services/sales_service.dart';
import 'auth_repository.dart';

/// Order history — mirrors berdikari-web `orders.ts` (list + status filter;
/// order actions like complete/refund come with a later phase).
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
}
