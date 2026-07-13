import 'package:berdikari_mobile/app.dart';
import 'package:berdikari_mobile/data/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Order _order(String id, String status) => Order(
      id: id,
      orderNo: 'INV-$id',
      status: status,
      paymentStatus: 'paid',
      totalAmount: 10000,
      paidAmount: 10000,
      changeAmount: 0,
      balanceDue: 0,
      customerName: null,
      createdAt: DateTime(2026, 1, 1),
      items: const [],
      payments: const [],
    );

void main() {
  testWidgets('order history filters by status', (tester) async {
    final auth = fakeAuthRepository(user: sampleUser(), token: 't');
    final sales = FakeSalesService(orders: [
      _order('1', 'completed'),
      _order('2', 'cancelled'),
    ]);
    await tester.pumpWidget(BerdikariApp(
      authRepository: auth,
      catalogService: FakeCatalogService(),
      salesService: sales,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kasir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('INV-2'), findsOneWidget);

    // "Selesai" also labels the completed order's status chip, so scope
    // the tap to the filter row's ChoiceChip specifically.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('INV-2'), findsNothing);
  });
}
