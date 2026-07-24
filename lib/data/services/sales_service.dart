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

  /// `POST /sales/orders/{id}/complete` — finishes a held (`open`) order,
  /// deducting stock. Optional [payments] settles it at the same time.
  Future<Order> completeOrder(
    String id, {
    List<Map<String, dynamic>>? payments,
  }) async {
    final response = await _api.post('/sales/orders/$id/complete', body: {
      if (payments != null) 'payments': payments,
    });
    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `POST /sales/orders/{id}/payments` — settles (part of) the balance on
  /// a completed-but-unpaid/partial order.
  Future<Order> payOrder(
    String id, {
    required int amount,
    String method = 'cash',
    String? note,
  }) async {
    final response = await _api.post('/sales/orders/$id/payments', body: {
      'amount': amount,
      'method': method,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `POST /sales/orders/{id}/cancel` — cancels a held (`open`) order. No
  /// stock/finance side effects.
  Future<Order> cancelOrder(String id) async {
    final response = await _api.post('/sales/orders/$id/cancel');
    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `POST /sales/orders/{id}/refund` — refunds a completed order: restores
  /// stock and reverses the recorded income.
  Future<Order> refundOrder(String id) async {
    final response = await _api.post('/sales/orders/$id/refund');
    return Order.fromJson(response['data'] as Map<String, dynamic>);
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

  /// `GET /sales/shifts` — shift history, most recent first.
  Future<List<CashierShift>> fetchShifts({String? status, String? date}) async {
    final response = await _api.get('/sales/shifts', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      'date': ?date,
    });
    return (response['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CashierShift.fromJson)
        .toList();
  }

  /// `GET /sales/shifts/{id}` — full detail for one past shift.
  Future<CashierShift> fetchShiftDetail(String id) async {
    final response = await _api.get('/sales/shifts/$id');
    return CashierShift.fromJson(response['data'] as Map<String, dynamic>);
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
