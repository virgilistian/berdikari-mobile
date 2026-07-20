import 'json_utils.dart';
import 'pending_order.dart';

/// Sales order — shape from berdikari-web `app/stores/orders.ts`.
/// Statuses: open | completed | cancelled | refunded.
/// Payment statuses: unpaid | partial | paid | refunded.
class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.balanceDue,
    required this.customerName,
    required this.createdAt,
    required this.items,
    required this.payments,
    this.pendingSync = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'].toString(),
        orderNo: json['order_no'] as String?,
        status: json['status'] as String? ?? 'open',
        paymentStatus: json['payment_status'] as String? ?? 'unpaid',
        totalAmount: parseRupiah(json['total_amount']),
        paidAmount: parseRupiah(json['paid_amount']),
        changeAmount: parseRupiah(json['change_amount']),
        balanceDue: parseRupiah(json['balance_due']),
        customerName: json['customer_name'] as String?,
        createdAt: parseDate(json['created_at']) ?? DateTime.now(),
        items: (json['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList(),
        payments: (json['payments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OrderPayment.fromJson)
            .toList(),
      );

  /// Receipt-shaped order synthesized locally for a checkout that's still
  /// sitting in the offline queue — mirrors berdikari-web `cart.ts`'s
  /// `enqueueOffline` return value. [pendingSync] drives the "belum
  /// tersinkron" indicator on the receipt.
  factory Order.fromPending(PendingOrder pending) {
    final items = (pending.payload['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((i) => OrderItem(
              productId: i['product_id'].toString(),
              quantity: (i['quantity'] as num?)?.toInt() ?? 0,
              unitPrice: (i['unit_price'] as num?)?.toInt() ?? 0,
              subtotal: ((i['quantity'] as num?)?.toInt() ?? 0) *
                  ((i['unit_price'] as num?)?.toInt() ?? 0),
              productName: i['name'] as String?,
            ))
        .toList();
    final payments = (pending.payload['payments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((p) => OrderPayment(
              amount: (p['amount'] as num?)?.toInt() ?? 0,
              method: p['method'] as String? ?? 'cash',
            ))
        .toList();
    final paid = payments.fold<int>(0, (sum, p) => sum + p.amount);
    final action = pending.payload['action'] as String? ?? 'complete';

    return Order(
      id: pending.clientUuid,
      orderNo: null,
      status: action == 'hold' ? 'open' : 'completed',
      paymentStatus: paid >= pending.totalAmount
          ? 'paid'
          : (paid > 0 ? 'partial' : 'unpaid'),
      totalAmount: pending.totalAmount,
      paidAmount: paid < pending.totalAmount ? paid : pending.totalAmount,
      changeAmount: paid > pending.totalAmount ? paid - pending.totalAmount : 0,
      balanceDue: pending.totalAmount > paid ? pending.totalAmount - paid : 0,
      customerName: pending.payload['customer_name'] as String?,
      createdAt: pending.createdAt,
      items: items,
      payments: payments,
      pendingSync: true,
    );
  }

  final String id;
  final String? orderNo;
  final String status;
  final String paymentStatus;
  final int totalAmount;
  final int paidAmount;
  final int changeAmount;
  final int balanceDue;
  final String? customerName;
  final DateTime createdAt;
  final List<OrderItem> items;
  final List<OrderPayment> payments;

  /// True when this order is still sitting in the offline queue and
  /// hasn't reached the server yet.
  final bool pendingSync;
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.productName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'].toString(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: parseRupiah(json['unit_price']),
        subtotal: parseRupiah(json['subtotal']),
        productName:
            json['product_name'] as String? ?? json['name'] as String?,
      );

  final String productId;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final String? productName;
}

class OrderPayment {
  const OrderPayment({required this.amount, required this.method});

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        amount: parseRupiah(json['amount']),
        method: json['method'] as String? ?? 'cash',
      );

  final int amount;
  final String method;
}
