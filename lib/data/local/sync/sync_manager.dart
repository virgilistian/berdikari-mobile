import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/catalog_repository.dart';
import '../../repositories/finance_repository.dart';
import '../app_database.dart';

/// Background sync coordinator for the local-first repositories (Catalog,
/// Finance — see the offline-first architecture plan). Drains each
/// repository's outbox then pulls a fresh read, on reconnect and on a
/// periodic foreground timer. Exposes aggregate status for the
/// `SyncStatusIndicator`; POS's own `OfflineQueueRepository` is not
/// registered here (it already has its own proven drain logic) — the
/// indicator widget watches both separately and merges their counts.
class SyncManager extends ChangeNotifier {
  SyncManager({
    required AppDatabase database,
    required CatalogRepository catalogRepository,
    required FinanceRepository financeRepository,
    Connectivity? connectivity,
    Duration periodicInterval = const Duration(minutes: 5),
  })  : _db = database,
        _catalog = catalogRepository,
        _finance = financeRepository,
        _connectivity = connectivity ?? Connectivity(),
        _periodicInterval = periodicInterval;

  final AppDatabase _db;
  final CatalogRepository _catalog;
  final FinanceRepository _finance;
  final Connectivity _connectivity;
  final Duration _periodicInterval;

  bool _isOffline = false;
  bool _syncing = false;
  String? _lastError;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOffline => _isOffline;
  bool get syncing => _syncing;
  String? get lastError => _lastError;
  int get pendingCount => _db.pendingCount;
  int get failedCount => _db.failedCount;

  Future<void> init() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOffline = _offlineFrom(initial);
    } catch (_) {
      _isOffline = false;
    }
    notifyListeners();

    try {
      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasOffline = _isOffline;
        _isOffline = _offlineFrom(result);
        notifyListeners();
        if (wasOffline && !_isOffline) unawaited(syncNow());
      });
    } catch (_) {
      // No platform channel (e.g. widget tests) — skip live updates.
    }

    _timer = Timer.periodic(_periodicInterval, (_) {
      if (!_isOffline) unawaited(syncNow());
    });

    // Deliberately no eager sync here: each repository already bootstraps
    // itself from the network the first time it's actually used (Catalog
    // screen opened, Finance list loaded, ...), same as before this
    // architecture existed. This coordinator only takes over from there —
    // on reconnect and on the periodic timer above.
  }

  bool _offlineFrom(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  /// Pushes pending writes then pulls fresh reads for every registered
  /// module. Safe to call any time — each repository's own push/pull is
  /// itself safe to retry (server dedup for creates, merge-skip for dirty
  /// rows on pull).
  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _catalog.pushPending();
      await _catalog.pullRefresh();
      await _finance.pushPending();
      await _finance.pullRefresh();
    } catch (_) {
      _lastError = 'Sinkronisasi gagal. Akan dicoba lagi.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
