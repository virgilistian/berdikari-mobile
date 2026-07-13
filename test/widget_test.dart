import 'package:berdikari_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the home shell in Bahasa Indonesia',
      (tester) async {
    await tester.pumpWidget(const BerdikariApp());
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang di Berdikari'), findsOneWidget);
    expect(find.text('ERP sederhana untuk usaha Anda'), findsOneWidget);
  });
}
