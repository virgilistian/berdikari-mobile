import 'package:berdikari_mobile/data/local/app_database.dart';
import 'package:berdikari_mobile/data/local/sync/sync_status.dart';
import 'package:berdikari_mobile/data/models/finance.dart';
import 'package:berdikari_mobile/data/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({String id = 'p1', String name = 'Es Teh'}) => Product(
      id: id,
      categoryId: 'c1',
      categoryName: 'Minuman',
      name: name,
      sku: null,
      price: 5000,
      costPrice: 2000,
      isActive: true,
      imageUrl: null,
    );

FinanceEntry _entry({String id = 'f1', DateTime? occurredAt}) => FinanceEntry(
      id: id,
      type: 'expense',
      amount: 10000,
      category: 'Belanja Bahan',
      note: null,
      occurredAt: occurredAt ?? DateTime(2026, 7, 1),
    );

void main() {
  group('AppDatabase products', () {
    test('mergeProductsFromServer stores rows readable via getProducts', () {
      final db = AppDatabase();
      db.mergeProductsFromServer([_product(id: 'p1'), _product(id: 'p2')]);
      expect(db.getProducts().map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('mergeProductsFromServer never overwrites a row with unsynced local edits', () {
      final db = AppDatabase();
      db.mergeProductsFromServer([_product(id: 'p1', name: 'Original')]);
      db.putLocalProduct(_product(id: 'p1', name: 'Edited locally'), SyncRowStatus.pendingUpdate);

      db.mergeProductsFromServer([_product(id: 'p1', name: 'Server value')]);

      expect(db.getProducts().single.name, 'Edited locally');
    });

    test('a pendingDelete row is hidden from getProducts', () {
      final db = AppDatabase();
      db.putLocalProduct(_product(id: 'p1'), SyncRowStatus.pendingDelete);
      expect(db.getProducts(), isEmpty);
    });

    test('mergeProductsFromServer drops synced rows the server no longer returns', () {
      final db = AppDatabase();
      db.mergeProductsFromServer([_product(id: 'p1'), _product(id: 'p2')]);
      db.mergeProductsFromServer([_product(id: 'p1')]);
      expect(db.getProducts().map((p) => p.id), ['p1']);
    });
  });

  group('AppDatabase finance entries', () {
    test('getFinanceEntries sorts newest first', () {
      final db = AppDatabase();
      db.mergeFinanceEntriesFromServer([
        _entry(id: 'f1', occurredAt: DateTime(2026, 7, 1)),
        _entry(id: 'f2', occurredAt: DateTime(2026, 7, 5)),
      ]);
      expect(db.getFinanceEntries().map((e) => e.id), ['f2', 'f1']);
    });
  });

  group('AppDatabase outbox', () {
    test('enqueue merges a repeated pending create for the same entity', () {
      final db = AppDatabase();
      final first = db.enqueue(
        entityType: 'product',
        entityId: 'local-1',
        operation: 'create',
        payload: {'name': 'A'},
      );
      final second = db.enqueue(
        entityType: 'product',
        entityId: 'local-1',
        operation: 'create',
        payload: {'name': 'B'},
      );

      expect(second.localId, first.localId);
      expect(db.pendingCountFor('product'), 1);
      expect(db.pendingJobs('product').single.payload['name'], 'B');
    });

    test('markSynced removes the job; markFailed keeps it visible as failed', () {
      final db = AppDatabase();
      final job = db.enqueue(
        entityType: 'finance_entry',
        entityId: 'local-1',
        operation: 'create',
        payload: const {},
      );

      db.markFailed(job.localId, 'Ditolak server');
      expect(db.pendingCount, 0);
      expect(db.failedJobs.single.lastError, 'Ditolak server');

      final job2 = db.enqueue(
        entityType: 'finance_entry',
        entityId: 'local-2',
        operation: 'create',
        payload: const {},
      );
      db.markSynced(job2.localId);
      expect(db.pendingCount, 0);
      expect(db.failedCount, 1);
    });

    test('discardPendingJobsFor drops every job for that entity', () {
      final db = AppDatabase();
      db.enqueue(entityType: 'product', entityId: 'local-1', operation: 'create', payload: const {});
      db.discardPendingJobsFor('product', 'local-1');
      expect(db.pendingCount, 0);
    });
  });

  group('AppDatabase dashboard cache', () {
    test('round-trips a snapshot per business', () {
      final db = AppDatabase();
      expect(db.getDashboardCache('b1'), isNull);
      db.putDashboardCache('b1', {'cash_net': 100000});
      expect(db.getDashboardCache('b1')!['cash_net'], 100000);
      expect(db.getDashboardCache('b2'), isNull);
    });
  });
}
