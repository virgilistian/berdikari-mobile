import 'package:berdikari_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Finance (Keuangan) flow — mirrors berdikari-web `finance/index.vue` +
/// `finance/new.vue`. DNA §5e.
void main() {
  testWidgets('kasir can record a new expense and see it in the list',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['finance.view', 'finance.create']),
      token: 't',
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      salesService: FakeSalesService(),
      financeService: FakeFinanceService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keuangan'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi'), findsOneWidget);

    await tester.tap(find.text('Tambah Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Catat Pengeluaran'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah'), '25000');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Belanja Bahan'));
    await tester.pumpAndSettle();
    // Scroll the form down so the save button is built and reachable —
    // scrollUntilVisible can't be used unscoped here since TextFormField's
    // internal EditableText also registers a Scrollable.
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(ElevatedButton, 'Simpan Pengeluaran');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Back on the list, scroll so the entry tile (below the summary cards)
    // is actually built and findable.
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The summary is now computed locally from the real cached entries (not
    // a disconnected fake that was always empty), so the category legitimately
    // appears twice: the entry tile and the by-category breakdown chip. The
    // category filter itself now lives behind the "Kategori" filter chip, so
    // it no longer renders every category inline.
    expect(find.text('Belanja Bahan'), findsNWidgets(2));
    expect(find.text('-Rp25.000'), findsNWidgets(3));
  });

  testWidgets('viewer without finance.create sees no add button', (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['finance.view']),
      token: 't',
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      salesService: FakeSalesService(),
      financeService: FakeFinanceService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keuangan'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Baru'), findsNothing);
  });

  testWidgets('kasir with finance.update can edit an existing entry', (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['finance.view', 'finance.update']),
      token: 't',
    );
    final financeService = FakeFinanceService(entries: [
      sampleFinanceEntry(id: 'f1', category: 'Belanja Bahan', amount: 20000),
    ]);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      salesService: FakeSalesService(),
      financeService: financeService,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keuangan'));
    await tester.pumpAndSettle();

    // The tile sits below the summary cards/chips (which repeat the same
    // category text) — scroll it into the built range and target it
    // specifically via its enclosing Card, not the category breakdown chip.
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Card, 'Belanja Bahan'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Transaksi'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sewa'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Back on the list, showing the edited category and unchanged amount.
    expect(find.text('Ubah Transaksi'), findsNothing);
    expect(find.widgetWithText(Card, 'Sewa'), findsOneWidget);
    expect(financeService.lastUpdatePayload!['category'], 'Sewa');
  });

  testWidgets('viewer without finance.update cannot open an entry for editing',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['finance.view']),
      token: 't',
    );
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      salesService: FakeSalesService(),
      financeService: FakeFinanceService(entries: [
        sampleFinanceEntry(id: 'f1', category: 'Belanja Bahan', amount: 20000),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keuangan'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Card, 'Belanja Bahan'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Transaksi'), findsNothing);
  });
}
