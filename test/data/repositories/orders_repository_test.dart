import 'package:berdikari_mobile/data/models/order.dart';
import 'package:berdikari_mobile/data/repositories/orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Order _order(String id, String status) => Order(
      id: id,
      orderNo: 'INV-$id',
      status: status,
      paymentStatus: 'paid',
      totalAmount: 10000,
      paidAmount: 10000,
      changeAmount: 0,
      balanceDue: 0,
      customerName: null,
      createdAt: DateTime(2026, 1, 1),
      items: const [],
      payments: const [],
    );

void main() {
  group('OrdersRepository', () {
    test('fetchOrders scopes to the active business and passes the filter',
        () async {
      final sales = FakeSalesService(orders: [
        _order('1', 'completed'),
        _order('2', 'cancelled'),
      ]);
      final auth = fakeAuthRepository(user: sampleUser(), token: 't');
      await auth.restoreSession();
      final repo = OrdersRepository(salesService: sales, authRepository: auth);

      final all = await repo.fetchOrders();
      expect(all, hasLength(2));

      final completedOnly = await repo.fetchOrders(status: 'completed');
      expect(completedOnly, hasLength(1));
      expect(completedOnly.first.id, '1');
    });
  });
}
