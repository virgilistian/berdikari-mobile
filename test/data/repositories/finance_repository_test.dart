import 'package:berdikari_mobile/data/local/app_database.dart';
import 'package:berdikari_mobile/data/models/finance.dart';
import 'package:berdikari_mobile/data/repositories/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('FinanceRepository', () {
    test('fetchAll loads entries + a locally-computed summary', () async {
      final service = FakeFinanceService(
        entries: [
          sampleFinanceEntry(id: 'f1', type: 'income', amount: 50000, category: 'Penjualan'),
          sampleFinanceEntry(id: 'f2', type: 'expense', amount: 20000, category: 'Belanja Bahan'),
        ],
      );
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );

      await repo.fetchAll();

      expect(repo.entries, hasLength(2));
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
        database: AppDatabase(),
      );
      await repo.fetchAll();
      expect(repo.entries, hasLength(2));

      await repo.setTypeFilter('income');

      expect(repo.typeFilter, 'income');
      expect(repo.entries.map((e) => e.id), ['f1']);
    });

    test('setCategoryFilter narrows entries to the chosen category', () async {
      final service = FakeFinanceService(entries: [
        sampleFinanceEntry(id: 'f1', type: 'expense', category: 'Belanja Bahan'),
        sampleFinanceEntry(id: 'f2', type: 'expense', category: 'Sewa'),
      ]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );
      await repo.fetchAll();
      expect(repo.availableCategories, ['Belanja Bahan', 'Sewa']);

      await repo.setCategoryFilter('Sewa');

      expect(repo.categoryFilter, 'Sewa');
      expect(repo.entries.map((e) => e.id), ['f2']);
    });

    test('setPeriod resets a previously chosen category filter', () async {
      final service = FakeFinanceService(entries: [
        sampleFinanceEntry(id: 'f1', category: 'Belanja Bahan'),
      ]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );
      await repo.fetchAll();
      await repo.setCategoryFilter('Belanja Bahan');
      expect(repo.categoryFilter, 'Belanja Bahan');

      await repo.setPeriod(FinancePeriod.month);

      expect(repo.categoryFilter, '');
    });

    test('setCustomRange filters entries to the chosen dates', () async {
      final service = FakeFinanceService(entries: [
        sampleFinanceEntry(id: 'f1', occurredAt: DateTime(2026, 1, 5)),
        sampleFinanceEntry(id: 'f2', occurredAt: DateTime(2026, 6, 15)),
      ]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );
      await repo.fetchAll();

      await repo.setPeriod(FinancePeriod.custom);
      await repo.setCustomRange(from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30));

      expect(repo.entries.map((e) => e.id), ['f2']);
    });

    test('createEntry writes locally immediately, then syncs to the service',
        () async {
      final service = FakeFinanceService();
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );
      await repo.fetchAll();

      final entry = await repo.createEntry(
        type: 'expense',
        amount: 15000,
        category: 'Belanja Bahan',
        note: 'Cabai dan bawang',
      );

      // Optimistic: visible locally right away, before any network call.
      expect(entry.category, 'Belanja Bahan');
      expect(entry.pendingSync, isTrue);
      expect(repo.entries, hasLength(1));

      // createEntry already fired its own background push — let it settle
      // instead of racing it with a second explicit call.
      await pumpEventQueue();
      expect(service.lastCreatePayload!['amount'], 15000);
      expect(repo.entries.single.pendingSync, isFalse);
    });

    test('deleteEntry removes through the service and refreshes the list', () async {
      final service = FakeFinanceService(entries: [sampleFinanceEntry(id: 'f1')]);
      final repo = FinanceRepository(
        financeService: service,
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
      );
      await repo.fetchAll();
      expect(repo.entries, hasLength(1));

      await repo.deleteEntry('f1');

      expect(repo.entries, isEmpty);
    });

    test('fetchAll failure with nothing cached surfaces an error', () async {
      final repo = FinanceRepository(
        financeService: _ThrowingFinanceService(),
        authRepository: fakeAuthRepository(user: sampleUser(), token: 't'),
        database: AppDatabase(),
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
