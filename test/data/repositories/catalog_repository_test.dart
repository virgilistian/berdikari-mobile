import 'package:berdikari_mobile/data/local/app_database.dart';
import 'package:berdikari_mobile/data/models/product.dart';
import 'package:berdikari_mobile/data/repositories/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('CatalogRepository', () {
    test('load returns only active products; loadAll returns everything',
        () async {
      final service = FakeCatalogService(products: [
        sampleProduct(id: 'p1', isActive: true),
        sampleProduct(id: 'p2', isActive: false),
      ]);
      final repo = CatalogRepository(catalogService: service, database: AppDatabase());

      final (active, _) = await repo.load();
      expect(active.map((p) => p.id), ['p1']);

      final (all, _) = await repo.loadAll();
      expect(all.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('caches after first load; refresh re-fetches', () async {
      final service = FakeCatalogService(
          products: [sampleProduct(id: 'p1')]);
      final repo = CatalogRepository(catalogService: service, database: AppDatabase());

      await repo.load();
      service.products = [
        ...service.products,
        sampleProduct(id: 'p2'),
      ];

      final (cached, _) = await repo.load();
      expect(cached.length, 1);

      final (refreshed, _) = await repo.load(refresh: true);
      expect(refreshed.length, 2);
    });

    test('saveProduct writes locally immediately, then syncs to the service',
        () async {
      final service = FakeCatalogService(products: []);
      final repo = CatalogRepository(catalogService: service, database: AppDatabase());
      await repo.load();

      final saved = await repo.saveProduct(
        name: 'Es Jeruk',
        categoryId: 'c1',
        price: 6000,
        costPrice: 2500,
        isActive: true,
      );

      // Optimistic: visible locally right away, before any network call.
      expect(saved.name, 'Es Jeruk');
      expect(saved.pendingSync, isTrue);
      final (all, _) = await repo.loadAll();
      expect(all.map((p) => p.name), contains('Es Jeruk'));

      // saveProduct already fired its own background push — let it settle
      // instead of racing it with a second explicit call.
      await pumpEventQueue();
      expect(service.products.map((p) => p.name), contains('Es Jeruk'));
      final (synced, _) = await repo.loadAll();
      expect(synced.firstWhere((p) => p.name == 'Es Jeruk').pendingSync, isFalse);
    });

    test('deleteProduct removes it and refreshes the cache', () async {
      final service =
          FakeCatalogService(products: [sampleProduct(id: 'p1')]);
      final repo = CatalogRepository(catalogService: service, database: AppDatabase());
      await repo.load();

      await repo.deleteProduct('p1');

      final (all, _) = await repo.loadAll();
      expect(all, isEmpty);
    });

    test('createCategory appends to the cached category list', () async {
      final service = FakeCatalogService(
          products: [], categories: [const ProductCategory(id: 'c1', name: 'Minuman')]);
      final repo = CatalogRepository(catalogService: service, database: AppDatabase());
      await repo.load();

      final created = await repo.createCategory('Cemilan');

      expect(created.name, 'Cemilan');
      final (_, categories) = await repo.loadAll();
      expect(categories.map((c) => c.name), contains('Cemilan'));
    });
  });
}
