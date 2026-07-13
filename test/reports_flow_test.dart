import 'package:berdikari_mobile/app.dart';
import 'package:berdikari_mobile/data/models/sales_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Laporan (Reports) — mirrors berdikari-web `reports/index.vue`. DNA §5e/§9.
void main() {
  testWidgets('report.view sees the aggregated KPIs; export is permission-gated',
      (tester) async {
    final auth = fakeAuthRepository(
      user: sampleUser(permissions: ['report.view', 'pos.view']),
      token: 't',
    );
    final sales = FakeSalesService()
      ..summary = const SalesSummary(
        orderCount: 4,
        grossSales: 120000,
        paidAmount: 120000,
        averageTicket: 30000,
        daily: [DailySales(date: '2026-07-13', total: 120000, orders: 4)],
        topProducts: [
          TopProduct(productId: 'p1', name: 'Es Teh', quantity: 10, subtotal: 50000),
        ],
        paymentMethods: {'cash': 90000, 'qris': 30000},
      );

    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      salesService: sales,
      financeService: FakeFinanceService(),
      inventoryService: FakeInventoryService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Total Penjualan'), findsOneWidget);
    expect(find.text('Rp120.000'), findsOneWidget);

    // "Produk Terlaris" sits below the fold in the reports ListView.
    await tester.dragUntilVisible(
      find.text('Es Teh'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Es Teh'), findsOneWidget);
    // No report.export permission -> no CSV export action.
    expect(find.byIcon(Icons.ios_share_outlined), findsNothing);
  });
}
