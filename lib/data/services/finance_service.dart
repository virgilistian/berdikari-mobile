import '../models/finance.dart';
import 'api_client.dart';

/// Finance module endpoints (`/v1/finance/*`) — cash flow (pemasukan/
/// pengeluaran) entries and summary. Mirrors berdikari-web `finance.ts`.
class FinanceService {
  FinanceService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<FinanceEntry>> fetchEntries({
    String? businessId,
    String? type,
    String? category,
    String? from,
    String? to,
  }) async {
    final response = await _api.get('/finance', query: {
      'business_id': ?businessId,
      if (type != null && type.isNotEmpty) 'type': type,
      if (category != null && category.isNotEmpty) 'category': category,
      'from': ?from,
      'to': ?to,
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FinanceEntry.fromJson)
        .toList();
  }

  Future<FinanceSummary> fetchSummary({
    String? businessId,
    String? from,
    String? to,
  }) async {
    final response = await _api.get('/finance/summary', query: {
      'business_id': ?businessId,
      'from': ?from,
      'to': ?to,
    });
    return FinanceSummary.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<FinanceEntry> createEntry({
    String? businessId,
    required String type,
    required int amount,
    required String category,
    String? note,
    String? occurredAt,
    String? shiftId,
    String? clientUuid,
  }) async {
    final response = await _api.post('/finance', body: {
      'business_id': ?businessId,
      'type': type,
      'amount': amount,
      'category': category,
      if (note != null && note.isNotEmpty) 'note': note,
      if (occurredAt != null && occurredAt.isNotEmpty) 'occurred_at': occurredAt,
      if (shiftId != null) 'shift_id': shiftId,
      if (clientUuid != null) 'client_uuid': clientUuid,
    });
    return FinanceEntry.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `PUT /finance/{id}` — only entries with `source_type=manual` can be
  /// edited; the server rejects auto-generated (POS) entries.
  Future<FinanceEntry> updateEntry(
    String id, {
    required String type,
    required int amount,
    required String category,
    String? note,
    String? occurredAt,
  }) async {
    final response = await _api.put('/finance/$id', body: {
      'type': type,
      'amount': amount,
      'category': category,
      if (note != null && note.isNotEmpty) 'note': note,
      if (occurredAt != null && occurredAt.isNotEmpty) 'occurred_at': occurredAt,
    });
    return FinanceEntry.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Operational expenses recorded against a specific cashier shift
  /// (`source_type=shift_expense`) — does not touch the global entries list.
  Future<List<FinanceEntry>> fetchShiftExpenses(String shiftId) async {
    final response = await _api.get('/finance', query: {
      'source_type': 'shift_expense',
      'source_id': shiftId,
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FinanceEntry.fromJson)
        .toList();
  }

  Future<void> deleteEntry(String id) => _api.delete('/finance/$id');
}
