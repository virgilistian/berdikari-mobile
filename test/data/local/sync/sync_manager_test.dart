import 'package:berdikari_mobile/data/local/app_database.dart';
import 'package:berdikari_mobile/data/local/sync/sync_manager.dart';
import 'package:berdikari_mobile/data/local/sync/sync_status.dart';
import 'package:berdikari_mobile/data/repositories/catalog_repository.dart';
import 'package:berdikari_mobile/data/repositories/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  group('SyncManager', () {
    test('syncNow pulls fresh reads into an empty local store', () async {
      final db = AppDatabase();
      final catalogService = FakeCatalogService(products: [sampleProduct(id: 'p1')]);
      final financeService = FakeFinanceService(entries: [sampleFinanceEntry(id: 'f1')]);
      final catalog = CatalogRepository(catalogService: catalogService, database: db);
      final finance = FinanceRepository(
        financeService: financeService,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: db,
      );
      final sync = SyncManager(database: db, catalogRepository: catalog, financeRepository: finance);

      expect(db.getProducts(), isEmpty);
      await sync.syncNow();

      final (products, _) = await catalog.loadAll();
      expect(products.map((p) => p.id), contains('p1'));
      expect(finance.entries.map((e) => e.id), contains('f1'));
    });

    test('syncNow drains an outbox job queued directly in the local store', () async {
      final db = AppDatabase();
      final catalogService = FakeCatalogService(products: []);
      final catalog = CatalogRepository(catalogService: catalogService, database: db);
      final finance = FinanceRepository(
        financeService: FakeFinanceService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: db,
      );
      final sync = SyncManager(database: db, catalogRepository: catalog, financeRepository: finance);

      // Simulate a write that already landed locally (as CatalogRepository's
      // optimistic writes do) without going through the repository's own
      // auto-push, so this test exercises SyncManager's coordination alone.
      db.putLocalProduct(sampleProduct(id: 'local-1', name: 'Es Jeruk'), SyncRowStatus.pendingCreate);
      db.enqueue(
        entityType: 'product',
        entityId: 'local-1',
        operation: 'create',
        payload: {
          'name': 'Es Jeruk',
          'category_id': null,
          'price': 6000,
          'cost_price': 2500,
          'sku': null,
          'is_active': true,
        },
      );
      expect(sync.pendingCount, 1);

      await sync.syncNow();

      expect(sync.pendingCount, 0);
      expect(catalogService.products.map((p) => p.name), contains('Es Jeruk'));
      final (products, _) = await catalog.loadAll();
      expect(products.firstWhere((p) => p.name == 'Es Jeruk').pendingSync, isFalse);
    });

    test('syncing flag toggles around syncNow', () async {
      final db = AppDatabase();
      final catalog = CatalogRepository(catalogService: FakeCatalogService(products: []), database: db);
      final finance = FinanceRepository(
        financeService: FakeFinanceService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: db,
      );
      final sync = SyncManager(database: db, catalogRepository: catalog, financeRepository: finance);

      expect(sync.syncing, isFalse);
      final future = sync.syncNow();
      expect(sync.syncing, isTrue);
      await future;
      expect(sync.syncing, isFalse);
    });
  });
}
