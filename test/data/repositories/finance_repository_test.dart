import 'package:berdikari_mobile/data/models/finance.dart';
import 'package:berdikari_mobile/data/repositories/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('FinanceRepository', () {
    test('fetchAll loads entries + summary', () async {
      final service = FakeFinanceService(
        entries: [sampleFinanceEntry(id: 'f1', type: 'income')],
        summary: const FinanceSummary(
          totalIncome: 50000,
          totalExpense: 20000,
          net: 30000,
          incomeByCategory: {'Penjualan': 50000},
          expenseByCategory: {'Belanja Bahan': 20000},
        ),
      );
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      await repo.fetchAll();

      expect(repo.entries, hasLength(1));
      expect(repo.summary.net, 30000);
      expect(repo.error, isNull);
    });

    test('setTypeFilter refetches with the type applied', () async {
      final service = FakeFinanceService(entries: [
        sampleFinanceEntry(id: 'f1', type: 'income'),
        sampleFinanceEntry(id: 'f2', type: 'expense'),
      ]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchAll();
      expect(repo.entries, hasLength(2));

      await repo.setTypeFilter('income');

      expect(repo.typeFilter, 'income');
      expect(repo.entries.map((e) => e.id), ['f1']);
    });

    test('createEntry saves through the service and refreshes the list', () async {
      final service = FakeFinanceService();
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchAll();

      final entry = await repo.createEntry(
        type: 'expense',
        amount: 15000,
        category: 'Belanja Bahan',
        note: 'Cabai dan bawang',
      );

      expect(entry.category, 'Belanja Bahan');
      expect(service.lastCreatePayload!['amount'], 15000);
      expect(repo.entries, hasLength(1));
    });

    test('deleteEntry removes through the service and refreshes the list', () async {
      final service = FakeFinanceService(entries: [sampleFinanceEntry(id: 'f1')]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );
      await repo.fetchAll();
      expect(repo.entries, hasLength(1));

      await repo.deleteEntry('f1');

      expect(repo.entries, isEmpty);
    });

    test('fetchAll failure surfaces an error and clears data', () async {
      final repo = FinanceRepository(
        financeService: _ThrowingFinanceService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
      );

      await repo.fetchAll();

      expect(repo.error, isNotNull);
      expect(repo.entries, isEmpty);
    });
  });
}

class _ThrowingFinanceService extends FakeFinanceService {
  @override
  Future<List<FinanceEntry>> fetchEntries({
    String? businessId,
    String? type,
    String? category,
    String? from,
    String? to,
  }) async =>
      throw Exception('network error');
}
