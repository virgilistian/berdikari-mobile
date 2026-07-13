import 'package:berdikari_mobile/data/models/stock.dart';
import 'package:berdikari_mobile/data/repositories/stock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('StockRepository', () {
    test('fetchStock loads rows + summary and flags low stock', () async {
      final service = FakeInventoryService(stockRows: [
        sampleStockRow(productId: 'p1', quantity: 2, minStock: 5),
        sampleStockRow(productId: 'p2', quantity: 20, minStock: 5),
      ]);
      final repo = StockRepository(
        inventoryService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      await repo.fetchStock();

      expect(repo.rows, hasLength(2));
      expect(repo.lowStockRows.map((r) => r.productId), ['p1']);
    });

    test('receive increases quantity and refreshes', () async {
      final service = FakeInventoryService(
          stockRows: [sampleStockRow(productId: 'p1', quantity: 10)]);
      final repo = StockRepository(
        inventoryService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchStock();

      await repo.receive(productId: 'p1', quantity: 5, reason: 'Belanja pasar');

      expect(repo.rows.first.quantity, 15);
      expect(service.lastReceivePayload!['reason'], 'Belanja pasar');
    });

    test('adjust sets the actual quantity and refreshes', () async {
      final service = FakeInventoryService(
          stockRows: [sampleStockRow(productId: 'p1', quantity: 10)]);
      final repo = StockRepository(
        inventoryService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchStock();

      await repo.adjust(productId: 'p1', quantity: 3, reason: 'Barang rusak');

      expect(repo.rows.first.quantity, 3);
    });

    test('setMinStock updates the threshold and refreshes', () async {
      final service = FakeInventoryService(
          stockRows: [sampleStockRow(productId: 'p1', minStock: 5)]);
      final repo = StockRepository(
        inventoryService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchStock();

      await repo.setMinStock(productId: 'p1', minStock: 10);

      expect(repo.rows.first.minStock, 10);
    });

    test('fetchMovements returns the ledger for one product', () async {
      final service = FakeInventoryService(movements: [
        StockMovement(
          id: '1',
          type: 'in',
          quantity: 20,
          reason: 'Belanja pasar',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      final repo = StockRepository(
        inventoryService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      final movements = await repo.fetchMovements('p1');

      expect(movements, hasLength(1));
      expect(movements.first.type, 'in');
    });
  });
}
