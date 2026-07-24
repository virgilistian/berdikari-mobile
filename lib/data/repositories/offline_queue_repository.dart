import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../local/pending_order_store.dart';
import '../models/pending_order.dart';
import '../services/api_client.dart';
import '../services/sales_service.dart';

/// Offline-first POS checkout queue. Every sale is written here first
/// (instant, no network wait) and drained to the server in the background
/// whenever the device is online. [ShiftRepository.close] calls
/// [flushAndVerify] so a shift can't close while sales are still stuck
/// locally.
///
/// Deliberately NOT a port of berdikari-web's `cart.ts` offline queue
/// (which tries the server first and only queues on failure) — mobile
/// always queues first, per product decision.
class OfflineQueueRepository extends ChangeNotifier {
  OfflineQueueRepository({
    required SalesService salesService,
    PendingOrderStore? store,
    Connectivity? connectivity,
  })  : _sales = salesService,
        _store = store ?? PendingOrderStore(),
        _connectivity = connectivity ?? Connectivity();

  final SalesService _sales;
  final PendingOrderStore _store;
  final Connectivity _connectivity;

  List<PendingOrder> _orders = [];
  bool _isOffline = false;
  bool _draining = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  List<PendingOrder> get orders => List.unmodifiable(_orders);
  List<PendingOrder> get queued =>
      _orders.where((o) => o.isQueued).toList();
  List<PendingOrder> get failedOrders =>
      _orders.where((o) => o.isFailed).toList();
  int get queuedCount => queued.length;
  bool get isOffline => _isOffline;
  bool get draining => _draining;

  Future<void> init() async {
    try {
      _orders = await _store.load();
    } catch (_) {
      _orders = [];
    }

    try {
      final initial = await _connectivity.checkConnectivity();
      _isOffline = _offlineFrom(initial);
    } catch (_) {
      // No platform channel available (e.g. widget tests) — assume online
      // so checkouts still sync instead of piling up unreachably.
      _isOffline = false;
    }
    notifyListeners();

    try {
      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasOffline = _isOffline;
        _isOffline = _offlineFrom(result);
        notifyListeners();
        if (wasOffline && !_isOffline) {
          unawaited(drain());
        }
      });
    } catch (_) {
      // Same as above — connectivity stream unavailable, skip live updates.
    }

    if (!_isOffline) {
      unawaited(drain());
    }
  }

  bool _offlineFrom(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  /// Writes a checkout payload to the queue immediately and persists it.
  Future<PendingOrder> enqueue(
    Map<String, dynamic> payload,
    int totalAmount,
  ) async {
    final pending = PendingOrder(
      clientUuid: payload['client_uuid'] as String,
      payload: payload,
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
      status: 'queued',
    );
    _orders = [..._orders, pending];
    await _store.save(_orders);
    notifyListeners();
    unawaited(drain());
    return pending;
  }

  /// Pushes every queued order to the server. Safe to call any time — the
  /// server deduplicates by `client_uuid`, so a retry after a partial sync
  /// never creates duplicates. Stops at the first network failure (leaves
  /// the rest queued for the next reconnect); a server rejection marks
  /// just that order `failed` and continues with the rest.
  Future<void> drain() async {
    if (_draining) return;
    final targets = queued;
    if (targets.isEmpty) return;

    _draining = true;
    notifyListeners();
    try {
      for (final pending in targets) {
        try {
          await _sales.submitOrder(pending.payload);
          _orders = _orders
              .where((o) => o.clientUuid != pending.clientUuid)
              .toList();
          await _store.save(_orders);
          notifyListeners();
        } on ApiException catch (e) {
          _orders = _orders
              .map((o) => o.clientUuid == pending.clientUuid
                  ? o.copyWith(status: 'failed', error: e.message)
                  : o)
              .toList();
          await _store.save(_orders);
          notifyListeners();
        } catch (_) {
          // Network-level failure — stop and retry on the next reconnect.
          _isOffline = true;
          notifyListeners();
          break;
        }
      }
    } finally {
      _draining = false;
      notifyListeners();
    }
  }

  /// Used by the shift-close gate: attempts a final drain and reports
  /// whether the queue is now clear of `queued` items. `failed` items
  /// don't block a close — they must be explicitly discarded.
  Future<bool> flushAndVerify() async {
    await drain();
    return queued.isEmpty;
  }

  Future<void> discard(String clientUuid) async {
    _orders = _orders.where((o) => o.clientUuid != clientUuid).toList();
    await _store.save(_orders);
    notifyListeners();
  }

  Future<void> discardAllFailed() async {
    _orders = _orders.where((o) => !o.isFailed).toList();
    await _store.save(_orders);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
