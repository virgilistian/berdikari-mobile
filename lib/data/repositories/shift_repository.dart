import 'package:flutter/foundation.dart';

import '../models/shift.dart';
import '../services/sales_service.dart';
import 'offline_queue_repository.dart';

/// Cashier shift state — mirrors berdikari-web `shift.ts`. Unlike web, POS
/// checkout is allowed without an open shift (dismissible reminder only —
/// see `pos/index.vue`'s "Always usable, shift or no shift"); what this
/// repository DOES gate is shift close, which requires the offline queue
/// to be fully synced first.
class ShiftRepository extends ChangeNotifier {
  ShiftRepository({
    required SalesService salesService,
    required OfflineQueueRepository offlineQueue,
  })  : _sales = salesService,
        _offlineQueue = offlineQueue;

  final SalesService _sales;
  final OfflineQueueRepository _offlineQueue;

  CashierShift? _activeShift;
  bool _loaded = false;

  CashierShift? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift?.isOpen ?? false;

  /// True once [fetchActive] has answered at least once — before that the
  /// POS screen shows a loading state rather than the "no shift" banner.
  bool get loaded => _loaded;

  Future<void> fetchActive() async {
    try {
      _activeShift = await _sales.fetchActiveShift();
    } catch (_) {
      _activeShift = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<CashierShift> open({required int openingCash}) async {
    final shift = await _sales.openShift(openingCash: openingCash);
    _activeShift = shift;
    _loaded = true;
    notifyListeners();
    return shift;
  }

  /// Closes the active shift and returns the summary (expected cash,
  /// difference). First forces a final sync of the offline queue — a
  /// shift can't close while sales are still stuck locally.
  Future<CashierShift> close({
    required int closingCash,
    String? closingNote,
  }) async {
    final active = _activeShift;
    if (active == null) {
      throw StateError('Tidak ada shift aktif');
    }
    final synced = await _offlineQueue.flushAndVerify();
    if (!synced) {
      throw ShiftCloseBlockedException(_offlineQueue.queuedCount);
    }
    final closed = await _sales.closeShift(
      active.id,
      closingCash: closingCash,
      closingNote: closingNote,
    );
    _activeShift = null;
    notifyListeners();
    return closed;
  }

  /// Called on logout so the next user starts clean.
  void reset() {
    _activeShift = null;
    _loaded = false;
    notifyListeners();
  }
}

/// Thrown by [ShiftRepository.close] when sales are still queued offline
/// and couldn't be synced (still offline).
class ShiftCloseBlockedException implements Exception {
  ShiftCloseBlockedException(this.queuedCount);

  final int queuedCount;
}
