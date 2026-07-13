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
  }) async {
    final response = await _api.post('/finance', body: {
      'business_id': ?businessId,
      'type': type,
      'amount': amount,
      'category': category,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return FinanceEntry.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteEntry(String id) => _api.delete('/finance/$id');
}
