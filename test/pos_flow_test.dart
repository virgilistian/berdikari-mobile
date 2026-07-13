import 'package:berdikari_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// End-to-end POS flow: open shift -> add products -> checkout -> receipt.
/// Mirrors the Project DNA §5a/§5b business workflows.
void main() {
  testWidgets('no active shift shows the open-shift prompt on /pos',
      (tester) async {
    final auth = fakeAuthRepository(user: sampleUser(), token: 't');
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kasir'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada shift aktif'), findsOneWidget);
    expect(find.text('Buka Shift'), findsOneWidget);
  });

  testWidgets(
      'open shift, add products to cart, checkout, and see the receipt',
      (tester) async {
    final auth = fakeAuthRepository(user: sampleUser(), token: 't');
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    // Open a shift first.
    await tester.tap(find.text('Kasir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka Shift'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Buka Shift'));
    await tester.pumpAndSettle();

    // Back to POS grid.
    await tester.tap(find.text('Kasir'));
    await tester.pumpAndSettle();
    expect(find.text('Es Teh'), findsOneWidget);

    // Add one product twice.
    await tester.tap(find.text('Es Teh'));
    await tester.tap(find.text('Es Teh'));
    await tester.pumpAndSettle();
    expect(find.text('2 item'), findsOneWidget);

    // Open cart sheet -> pay. The pay bar's "Bayar" button stays mounted
    // behind the modal, so scope the tap to the sheet's own button (last
    // in tree order — the modal route is inserted above the page).
    await tester.tap(find.text('Bayar'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Bayar').last);
    await tester.pumpAndSettle();

    // Payment sheet pre-fills the exact total (2 x 5000 = 10000).
    expect(find.text('Pembayaran'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Proses Pembayaran'));
    await tester.pumpAndSettle();

    // Receipt.
    expect(find.text('Transaksi Berhasil'), findsOneWidget);
    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();

    // Cart cleared; pay bar gone.
    expect(find.text('Bayar'), findsNothing);
  });

  testWidgets('viewer without pos permission never sees Kasir in nav',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: const [], roles: const ['viewer']),
      token: 't',
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: FakeSalesService(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kasir'), findsNothing);
  });
}
