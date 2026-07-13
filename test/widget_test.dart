import 'package:berdikari_mobile/app.dart';
import 'package:berdikari_mobile/data/models/finance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('unauthenticated boot lands on the login screen in Bahasa',
      (tester) async {
    await tester.pumpWidget(BerdikariApp(authRepository: fakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk untuk mengelola usaha Anda'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
  });

  testWidgets('login flow authenticates and shows the permission-driven shell',
      (tester) async {
    final repo = fakeAuthRepository(user: sampleUser());
    await tester.pumpWidget(BerdikariApp(
      authRepository: repo,
      salesService: FakeSalesService(),
      inventoryService: FakeInventoryService(),
      financeService: FakeFinanceService(
        summary: const FinanceSummary(
          totalIncome: 80000,
          totalExpense: 30000,
          net: 50000,
          incomeByCategory: {},
          expenseByCategory: {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'sari@berdikari.id');
    await tester.enterText(find.byType(TextFormField).last, 'rahasia');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Home greeting.
    expect(find.text('Halo, Ibu Sari'), findsOneWidget);
    // Dashboard KPI wired to the (fake) finance summary.
    expect(find.text('Kas Hari Ini'), findsOneWidget);
    expect(find.text('Rp50.000'), findsOneWidget);
    // Bottom nav: cashier with finance.view + pos.* sees these...
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Keuangan'), findsOneWidget);
    expect(find.text('Kasir'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    // ...but not inventory (no inventory.view).
    expect(find.text('Stok'), findsNothing);
  });

  testWidgets('restored session skips login and opens the shell',
      (tester) async {
    final repo = fakeAuthRepository(user: sampleUser(), token: 'persisted');
    await tester.pumpWidget(BerdikariApp(
      authRepository: repo,
      salesService: FakeSalesService(),
      inventoryService: FakeInventoryService(),
      financeService: FakeFinanceService(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Halo, Ibu Sari'), findsOneWidget);
    expect(find.text('Masuk untuk mengelola usaha Anda'), findsNothing);
  });

  testWidgets('Lainnya sheet reaches Pengaturan (account hub)',
      (tester) async {
    final repo = fakeAuthRepository(user: sampleUser(), token: 'persisted');
    await tester.pumpWidget(BerdikariApp(
      authRepository: repo,
      salesService: FakeSalesService(),
      inventoryService: FakeInventoryService(),
      financeService: FakeFinanceService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Ubah Kata Sandi'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });
}
