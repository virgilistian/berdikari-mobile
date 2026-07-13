import 'package:berdikari_mobile/data/repositories/cart_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('CartRepository', () {
    test('adding the same product twice increments quantity', () {
      final auth = fakeAuthRepository(user: sampleUser());
      final cart = CartRepository(
        salesService: FakeSalesService(),
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
        salesService: FakeSalesService(),
        authRepository: fakeAuthRepository(user: sampleUser()),
      );
      cart.addProduct(sampleProduct(id: 'p1'));

      cart.decrease('p1');

      expect(cart.isEmpty, isTrue);
    });

    test('checkout submits items + payment and clears the cart', () async {
      final sales = FakeSalesService();
      final auth = fakeAuthRepository(user: sampleUser(), token: 't');
      await auth.restoreSession();
      final cart = CartRepository(salesService: sales, authRepository: auth);
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));
      cart.addProduct(sampleProduct(id: 'p2', price: 3000));
      cart.increase('p2'); // 2x Nasi Kucing = 6000

      final order = await cart.checkout(payment: 15000, method: 'cash');

      expect(order.paidAmount, 15000);
      expect(order.totalAmount, 11000);
      expect(order.changeAmount, 4000);
      expect(cart.isEmpty, isTrue);

      final payload = sales.lastCheckoutPayload!;
      expect(payload['action'], 'complete');
      expect(payload['items'], hasLength(2));
      expect(payload['payments'], [
        {'amount': 15000, 'method': 'cash'}
      ]);
    });

    test('checkout on empty cart throws', () {
      final cart = CartRepository(
        salesService: FakeSalesService(),
        authRepository: fakeAuthRepository(),
      );

      expect(() => cart.checkout(payment: 1000), throwsStateError);
    });

    test('checkout without payment sends an empty payments list (pay later)',
        () async {
      final sales = FakeSalesService();
      final cart = CartRepository(
        salesService: sales,
        authRepository: fakeAuthRepository(user: sampleUser()),
      );
      cart.addProduct(sampleProduct(id: 'p1', price: 5000));

      await cart.checkout();

      expect(sales.lastCheckoutPayload!['payments'], isEmpty);
    });
  });
}
