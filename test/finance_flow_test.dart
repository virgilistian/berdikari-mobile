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
    final saveButton = find.widgetWithText(ElevatedButton, 'Simpan Pengeluaran');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Belanja Bahan'), findsOneWidget);
    expect(find.text('-Rp25.000'), findsOneWidget);
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
