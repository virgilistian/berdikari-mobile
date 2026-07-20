import 'package:berdikari_mobile/data/repositories/cart_repository.dart';
import 'package:berdikari_mobile/data/repositories/offline_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('CartRepository', () {
    test('adding the same product twice increments quantity', () {
      final auth = fakeAuthRepository(user: sampleUser());
      final cart = CartRepository(
        offlineQueue: OfflineQueueRepository(salesService: FakeSalesService()),
        authRepository: auth,
      );

      cart.addProduct(sampleProduct(id: 'p1', price: 5000));
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 2);
      expect(cart.totalAmount, 10000);
      expect(cart.totalItems, 2);
    });

    test('decrease below 1 removes the line', () {
      final cart = CartRepository(
        offlineQueue: OfflineQueueRepository(salesService: FakeSalesService()),
        authRepository: fakeAuthRepository(user: sampleUser()),
      );
      cart.addProduct(sampleProduct(id: 'p1'));

      cart.decrease('p1');

      expect(cart.isEmpty, isTrue);
    });

    test('checkout enqueues offline-first, drains, and clears the cart',
        () async {
      final sales = FakeSalesService();
      final offlineQueue = OfflineQueueRepository(salesService: sales);
      final auth = fakeAuthRepository(user: sampleUser(), token: 't');
      await auth.restoreSession();
      final cart = CartRepository(offlineQueue: offlineQueue, authRepository: auth);
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));
      cart.addProduct(sampleProduct(id: 'p2', price: 3000));
      cart.increase('p2'); // 2x Nasi Kucing = 6000

      final order = await cart.checkout(payment: 15000, method: 'cash');
      expect(cart.isEmpty, isTrue);
      // enqueue() fires drain() without awaiting it — force it to settle.
      await offlineQueue.drain();

      // The returned order is synthesized locally from the queued payload
      // (offline-first — see Order.fromPending), so paid/change mirror the
      // same capping berdikari-web's `enqueueOffline` applies.
      expect(order.totalAmount, 11000);
      expect(order.paidAmount, 11000);
      expect(order.changeAmount, 4000);
      expect(order.paymentStatus, 'paid');

      final payload = sales.lastCheckoutPayload!;
      expect(payload['action'], 'complete');
      expect(payload['items'], hasLength(2));
      expect(payload['payments'], [
        {'amount': 15000, 'method': 'cash'}
      ]);
      expect(offlineQueue.queuedCount, 0);
    });

    test('checkout on empty cart throws', () {
      final cart = CartRepository(
        offlineQueue: OfflineQueueRepository(salesService: FakeSalesService()),
        authRepository: fakeAuthRepository(),
      );

      expect(() => cart.checkout(payment: 1000), throwsStateError);
    });

    test('checkout without payment sends an empty payments list (pay later)',
        () async {
      final sales = FakeSalesService();
      final offlineQueue = OfflineQueueRepository(salesService: sales);
      final cart = CartRepository(
        offlineQueue: offlineQueue,
        authRepository: fakeAuthRepository(user: sampleUser()),
      );
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));

      await cart.checkout();
      await offlineQueue.drain();

      expect(sales.lastCheckoutPayload!['payments'], isEmpty);
    });

    test('hold() submits with action=hold', () async {
      final sales = FakeSalesService();
      final offlineQueue = OfflineQueueRepository(salesService: sales);
      final cart = CartRepository(
        offlineQueue: offlineQueue,
        authRepository: fakeAuthRepository(user: sampleUser()),
      );
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));

      final order = await cart.hold();
      await offlineQueue.drain();

      expect(order.status, 'open');
      expect(sales.lastCheckoutPayload!['action'], 'hold');
    });
  });
}
