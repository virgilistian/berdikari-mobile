import 'package:berdikari_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Catalog CRUD flow — mirrors berdikari-web `catalog/index.vue`.
void main() {
  Future<void> openCatalog(WidgetTester tester) async {
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katalog'));
    await tester.pumpAndSettle();
  }

  testWidgets('manager can add a new product to the catalog', (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(
        permissions: ['catalog.view', 'catalog.create', 'catalog.update'],
        roles: ['manager'],
      ),
      token: 't',
    );
    final catalogService = FakeCatalogService(products: []);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: catalogService,
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    await openCatalog(tester);
    expect(find.text('Belum ada produk'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Produk Baru'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama produk'), 'Es Jeruk');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Harga jual'), '6000');
    final saveButton = find.widgetWithText(ElevatedButton, 'Simpan');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Produk Baru'), findsNothing);
    expect(find.text('Es Jeruk'), findsOneWidget);
  });

  testWidgets('viewer without manage permissions sees no add/edit controls',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['catalog.view'], roles: ['viewer']),
      token: 't',
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    await openCatalog(tester);

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('editing an existing product can delete it', (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(
        permissions: ['catalog.view', 'catalog.create', 'catalog.update'],
        roles: ['manager'],
      ),
      token: 't',
    );
    final catalogService =
        FakeCatalogService(products: [sampleProduct(id: 'p1', name: 'Es Teh')]);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: catalogService,
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    await openCatalog(tester);
    final editIcon = find.byIcon(Icons.edit_outlined);
    await tester.ensureVisible(editIcon);
    await tester.pumpAndSettle();
    await tester.tap(editIcon);
    await tester.pumpAndSettle();
    expect(find.text('Ubah Produk'), findsOneWidget);

    final deleteButton = find.text('Hapus produk');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Es Teh'), findsNothing);
    expect(find.text('Belum ada produk'), findsOneWidget);
  });
}
