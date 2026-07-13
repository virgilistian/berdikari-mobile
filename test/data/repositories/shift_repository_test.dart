import 'package:berdikari_mobile/data/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('ShiftRepository', () {
    test('fetchActive with no open shift -> hasActiveShift false', () async {
      final repo = ShiftRepository(salesService: FakeSalesService());

      await repo.fetchActive();

      expect(repo.loaded, isTrue);
      expect(repo.hasActiveShift, isFalse);
    });

    test('fetchActive picks up an already-open shift', () async {
      final sales = FakeSalesService(activeShift: sampleShift(openingCash: 50000));
      final repo = ShiftRepository(salesService: sales);

      await repo.fetchActive();

      expect(repo.hasActiveShift, isTrue);
      expect(repo.activeShift?.openingCash, 50000);
    });

    test('open then close computes the summary and clears the active shift',
        () async {
      final repo = ShiftRepository(salesService: FakeSalesService());

      await repo.open(openingCash: 100000);
      expect(repo.hasActiveShift, isTrue);

      final summary = await repo.close(closingCash: 120000, closingNote: 'ok');

      expect(repo.hasActiveShift, isFalse);
      expect(summary.status, 'closed');
      expect(summary.closingCash, 120000);
      expect(summary.cashDifference, 20000);
    });

    test('close with no active shift throws', () {
      final repo = ShiftRepository(salesService: FakeSalesService());

      expect(() => repo.close(closingCash: 1000), throwsStateError);
    });

    test('reset clears state for the next user', () async {
      final repo = ShiftRepository(salesService: FakeSalesService());
      await repo.open(openingCash: 10000);

      repo.reset();

      expect(repo.hasActiveShift, isFalse);
      expect(repo.loaded, isFalse);
    });
  });
}
