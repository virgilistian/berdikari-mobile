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
      final repo = CatalogRepository(catalogService: service);

      final (active, _) = await repo.load();
      expect(active.map((p) => p.id), ['p1']);

      final (all, _) = await repo.loadAll();
      expect(all.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('caches after first load; refresh re-fetches', () async {
      final service = FakeCatalogService(
          products: [sampleProduct(id: 'p1')]);
      final repo = CatalogRepository(catalogService: service);

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

    test('saveProduct creates then refreshes the cache', () async {
      final service = FakeCatalogService(products: []);
      final repo = CatalogRepository(catalogService: service);
      await repo.load();

      final saved = await repo.saveProduct(
        name: 'Es Jeruk',
        categoryId: 'c1',
        price: 6000,
        costPrice: 2500,
        isActive: true,
      );

      expect(saved.name, 'Es Jeruk');
      final (all, _) = await repo.loadAll();
      expect(all.map((p) => p.name), contains('Es Jeruk'));
    });

    test('deleteProduct removes it and refreshes the cache', () async {
      final service =
          FakeCatalogService(products: [sampleProduct(id: 'p1')]);
      final repo = CatalogRepository(catalogService: service);
      await repo.load();

      await repo.deleteProduct('p1');

      final (all, _) = await repo.loadAll();
      expect(all, isEmpty);
    });

    test('createCategory appends to the cached category list', () async {
      final service = FakeCatalogService(
          products: [], categories: [const ProductCategory(id: 'c1', name: 'Minuman')]);
      final repo = CatalogRepository(catalogService: service);
      await repo.load();

      final created = await repo.createCategory('Cemilan');

      expect(created.name, 'Cemilan');
      final (_, categories) = await repo.loadAll();
      expect(categories.map((c) => c.name), contains('Cemilan'));
    });
  });
}
