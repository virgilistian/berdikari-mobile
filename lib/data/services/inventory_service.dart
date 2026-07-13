import '../models/daily_stock.dart';
import '../models/stock.dart';
import 'api_client.dart';

/// Inventory module endpoints (`/v1/inventory/*`) — both the daily-stock
/// opname sub-group and the stock & valuation endpoints, mirroring
/// berdikari-web `dailyStock.ts` and `inventory.ts`.
class InventoryService {
  InventoryService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static String get _today => DateTime.now().toIso8601String().split('T').first;

  // ── Daily stock opname ──────────────────────────────────────────────

  Future<List<DailyStockItem>> fetchTodayStock({String? businessId}) async {
    final response = await _api.get(
      '/inventory/daily-stock/$_today',
      query: {'business_id': ?businessId},
    );
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DailyStockItem.fromJson)
        .toList();
  }

  Future<List<ProductForStock>> fetchStockProducts({String? businessId}) async {
    final response = await _api.get(
      '/inventory/daily-stock/products',
      query: {'business_id': ?businessId},
    );
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductForStock.fromJson)
        .toList();
  }

  Future<List<DailyStockItem>> openDay({
    String? businessId,
    required List<({String productId, String productName, int openingQty})>
        items,
  }) async {
    final response = await _api.post('/inventory/daily-stock/open', body: {
      'business_id': ?businessId,
      'date': _today,
      'items': [
        for (final item in items)
          {
            'product_id': item.productId,
            'product_name': item.productName,
            'opening_qty': item.openingQty,
          },
      ],
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DailyStockItem.fromJson)
        .toList();
  }

  Future<List<DailyStockItem>> closeDay({String? businessId}) async {
    final response = await _api.post('/inventory/daily-stock/close', body: {
      'business_id': ?businessId,
      'date': _today,
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DailyStockItem.fromJson)
        .toList();
  }

  // ── Stock & valuation ────────────────────────────────────────────────

  Future<(List<StockRow>, StockSummary)> fetchStock({String? businessId}) async {
    final query = {'business_id': ?businessId};
    final results = await Future.wait([
      _api.get('/inventory', query: query),
      _api.get('/inventory/summary', query: query),
    ]);
    final rows = (results[0]['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StockRow.fromJson)
        .toList();
    final summary = StockSummary.fromJson(results[1]['data'] as Map<String, dynamic>);
    return (rows, summary);
  }

  Future<void> receive({
    String? businessId,
    required String productId,
    required int quantity,
    String? reason,
  }) =>
      _api.post('/inventory/receive', body: {
        'business_id': ?businessId,
        'product_id': productId,
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> adjust({
    String? businessId,
    required String productId,
    required int quantity,
    String? reason,
  }) =>
      _api.post('/inventory/adjust', body: {
        'business_id': ?businessId,
        'product_id': productId,
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> setMinStock({
    String? businessId,
    required String productId,
    required int minStock,
  }) =>
      _api.put('/inventory/$productId/min-stock', body: {
        'business_id': ?businessId,
        'min_stock': minStock,
      });

  /// `GET /inventory/low-stock` — lighter than [fetchStock] for screens
  /// (dashboard, reports) that only need the low-stock count/list.
  Future<List<StockRow>> fetchLowStock({String? businessId}) async {
    final response = await _api.get(
      '/inventory/low-stock',
      query: {'business_id': ?businessId},
    );
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StockRow.fromJson)
        .toList();
  }

  Future<List<StockMovement>> fetchMovements({
    String? businessId,
    required String productId,
  }) async {
    final response = await _api.get(
      '/inventory/$productId/movements',
      query: {'business_id': ?businessId},
    );
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StockMovement.fromJson)
        .toList();
  }
}
