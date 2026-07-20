/// A checkout captured locally, waiting to be synced to the API — mirrors
/// berdikari-web `cart.ts`'s `PendingOrder`. Mobile enqueues every checkout
/// here first (offline-first), rather than trying the server and falling
/// back like web does.
class PendingOrder {
  PendingOrder({
    required this.clientUuid,
    required this.payload,
    required this.totalAmount,
    required this.createdAt,
    required this.status,
    this.error,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        clientUuid: json['client_uuid'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        status: json['status'] as String? ?? 'queued',
        error: json['error'] as String?,
      );

  final String clientUuid;
  final Map<String, dynamic> payload;
  final int totalAmount;
  final DateTime createdAt;

  /// `queued` retries automatically when back online; `failed` was
  /// rejected by the server and must be explicitly discarded.
  final String status;
  final String? error;

  bool get isQueued => status == 'queued';
  bool get isFailed => status == 'failed';

  PendingOrder copyWith({String? status, String? error}) => PendingOrder(
        clientUuid: clientUuid,
        payload: payload,
        totalAmount: totalAmount,
        createdAt: createdAt,
        status: status ?? this.status,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'payload': payload,
        'total_amount': totalAmount,
        'created_at': createdAt.toIso8601String(),
        'status': status,
        if (error != null) 'error': error,
      };
}
