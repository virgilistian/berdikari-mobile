import '../models/order.dart';
import '../models/sales_summary.dart';
import '../models/shift.dart';
import 'api_client.dart';

/// Sales module endpoints (`/v1/sales/*`) — orders and cashier shifts.
/// Payload shapes mirror berdikari-web `cart.ts` / `shift.ts` / `orders.ts`.
class SalesService {
  SalesService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// `POST /sales/orders`. The payload carries a `client_uuid` idempotency
  /// key so a retry can never create a duplicate order.
  Future<Order> submitOrder(Map<String, dynamic> payload) async {
    final response = await _api.post('/sales/orders', body: payload);
    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<Order>> fetchOrders({
    String? businessId,
    String? status,
    String? date,
  }) async {
    final response = await _api.get('/sales/orders', query: {
      'business_id': ?businessId,
      if (status != null && status.isNotEmpty) 'status': status,
      'date': ?date,
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Order.fromJson)
        .toList();
  }

  /// `GET /sales/summary` — aggregated sales for the Reports screen.
  Future<SalesSummary> fetchSummary({
    String? businessId,
    String? from,
    String? to,
  }) async {
    final response = await _api.get('/sales/summary', query: {
      'business_id': ?businessId,
      'from': ?from,
      'to': ?to,
    });
    return SalesSummary.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `GET /sales/shifts/active` — `data` is null when no shift is open.
  Future<CashierShift?> fetchActiveShift() async {
    final response = await _api.get('/sales/shifts/active');
    final data = response['data'];
    return data is Map<String, dynamic> ? CashierShift.fromJson(data) : null;
  }

  Future<CashierShift> openShift({required int openingCash}) async {
    final response = await _api.post(
      '/sales/shifts/open',
      body: {'opening_cash': openingCash},
    );
    return CashierShift.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<CashierShift> closeShift(
    String id, {
    required int closingCash,
    String? closingNote,
  }) async {
    final response = await _api.post(
      '/sales/shifts/$id/close',
      body: {
        'closing_cash': closingCash,
        if (closingNote != null && closingNote.isNotEmpty)
          'closing_note': closingNote,
      },
    );
    return CashierShift.fromJson(response['data'] as Map<String, dynamic>);
  }
}
