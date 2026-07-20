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

    // The summary is now computed locally from the real cached entries
    // (not a disconnected fake that was always empty), so both the
    // category and amount legitimately appear more than once: the entry
    // tile, the by-category breakdown chip, and — for the amount only —
    // the "Bersih" net card (net == -25000 here since there's no income).
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
}
