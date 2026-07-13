import 'package:berdikari_mobile/app.dart';
import 'package:berdikari_mobile/data/models/daily_stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Daily stock opname + stock & valuation flows — mirrors berdikari-web
/// `inventory/index.vue`, `inventory/new.vue`, `inventory/stock.vue`.
/// Business workflow: DNA §5c/§5d.
void main() {
  // The default 800x600 test surface is narrower than the KPI grid +
  // list content needs — on a real phone (~390x850) everything fits
  // without scrolling, but the tiny test viewport pushes list rows into
  // the Sliver's unlaid-out region, where finders can't see them even
  // though they're logically in the tree. Match a real phone instead.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Future<void> openInventory(WidgetTester tester) async {
    await tester.tap(find.text('Stok'));
    await tester.pumpAndSettle();
  }

  testWidgets('open stock, set a quantity, save, and see the live table',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(
        permissions: ['inventory.view', 'inventory.create'],
        roles: ['inventory-staff'],
      ),
      token: 't',
    );
    final inventoryService = FakeInventoryService(stockProducts: [
      const ProductForStock(
          id: 'p1', name: 'Es Teh', price: 5000, currentStock: 0),
    ]);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
      inventoryService: inventoryService,
    ));
    await tester.pumpAndSettle();

    await openInventory(tester);
    expect(find.text('Stok hari ini belum dibuka'), findsOneWidget);

    await tester.tap(find.text('Buka Stok'));
    await tester.pumpAndSettle();
    expect(find.text('Buka Stok Hari Ini'), findsWidgets);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Buka Stok Hari Ini'));
    await tester.pumpAndSettle();

    expect(find.text('Es Teh'), findsOneWidget);
    expect(inventoryService.lastOpenPayload, isNotNull);
  });

  testWidgets('an already-open day can be closed', (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['inventory.view'], roles: ['manager']),
      token: 't',
    );
    final inventoryService = FakeInventoryService(todayStock: const [
      DailyStockItem(
        id: 'ds1',
        productId: 'p1',
        productName: 'Es Teh',
        openingQty: 10,
        soldQty: 3,
        closingQty: null,
        status: 'open',
      ),
    ]);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
      inventoryService: inventoryService,
    ));
    await tester.pumpAndSettle();

    await openInventory(tester);
    expect(find.text('Es Teh'), findsOneWidget);

    await tester.tap(find.text('Tutup Hari Ini'));
    await tester.pumpAndSettle();

    expect(find.text('Hari telah ditutup — Rekap akhir hari'), findsOneWidget);
  });

  testWidgets('receiving stock updates the quantity on Stok & Valuasi',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['inventory.view'], roles: ['manager']),
      token: 't',
    );
    final inventoryService = FakeInventoryService(
      stockRows: [sampleStockRow(productId: 'p1', quantity: 10)],
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
      inventoryService: inventoryService,
    ));
    await tester.pumpAndSettle();

    await openInventory(tester);
    await tester.tap(find.text('Stok & Valuasi'));
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Jumlah masuk'), '5');
    // The Simpan button's enabled state is gated by a build-time-computed
    // local (`quantity`), which only reflects the new text after the
    // `onChanged` -> setState rebuild — enterText() alone doesn't flush
    // that, so an explicit pump is required before the button un-disables.
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
  });
}
