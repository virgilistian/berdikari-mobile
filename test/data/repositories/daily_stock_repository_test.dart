import 'package:berdikari_mobile/data/models/daily_stock.dart';
import 'package:berdikari_mobile/data/repositories/daily_stock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('DailyStockRepository', () {
    test('fetchToday with nothing opened -> hasStocks false', () async {
      final repo = DailyStockRepository(
        inventoryService: FakeInventoryService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      await repo.fetchToday();

      expect(repo.hasStocks, isFalse);
      expect(repo.isOpen, isFalse);
      expect(repo.isClosed, isFalse);
    });

    test('openDay populates stocks and flips isOpen', () async {
      final repo = DailyStockRepository(
        inventoryService: FakeInventoryService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      await repo.openDay(const [
        (productId: 'p1', productName: 'Es Teh', openingQty: 20),
      ]);

      expect(repo.hasStocks, isTrue);
      expect(repo.isOpen, isTrue);
      expect(repo.stocks.first.remainingQty, 20);
    });

    test('closeDay computes closing qty and flips isClosed', () async {
      final repo = DailyStockRepository(
        inventoryService: FakeInventoryService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.openDay(const [
        (productId: 'p1', productName: 'Es Teh', openingQty: 20),
      ]);

      await repo.closeDay();

      expect(repo.isOpen, isFalse);
      expect(repo.isClosed, isTrue);
      expect(repo.stocks.first.closingQty, 20);
    });

    test('DailyStockItem.remainingQty subtracts sold from opening', () {
      const item = DailyStockItem(
        id: '1',
        productId: 'p1',
        productName: 'Es Teh',
        openingQty: 20,
        soldQty: 7,
        closingQty: null,
        status: 'open',
      );

      expect(item.remainingQty, 13);
    });
  });
}
