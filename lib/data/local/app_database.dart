import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance.dart' show FinanceEntry;
import '../models/product.dart' show Product, ProductCategory;
import 'sync/sync_status.dart';

/// Local-first data store for Catalog + Finance + Dashboard cache, plus the
/// write outbox that backs their background sync.
///
/// Reads/writes are served from in-memory maps — always available,
/// synchronous-fast, and safe under `flutter test` (no platform channel in
/// the hot path). [open] additionally mirrors every write to an on-disk
/// sqflite database best-effort, so data survives an app restart on a real
/// device; if that fails (unsupported platform, or no platform channel
/// under a widget test that never calls [open]), the app keeps working
/// from the in-memory store for the session — same "degrade, don't crash"
/// philosophy as `PendingOrderStore`/`OfflineQueueRepository`.
class AppDatabase {
  final Map<String, Map<String, dynamic>> _products = {};
  final Map<String, Map<String, dynamic>> _categories = {};
  final Map<String, Map<String, dynamic>> _financeEntries = {};
  final Map<String, Map<String, dynamic>> _dashboardCache = {};
  final List<OutboxJob> _outbox = [];
  int _nextOutboxId = 1;

  Database? _sqlite;

  /// True once a real on-disk database is backing this store.
  bool get isPersistent => _sqlite != null;

  /// Opens (or creates) the on-disk mirror and hydrates the in-memory store
  /// from it. Safe to skip (e.g. in widget tests) — the store just stays
  /// in-memory for that run.
  Future<void> open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'berdikari_offline.db');
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE kv_store ('
            'table_name TEXT NOT NULL, row_id TEXT NOT NULL, data TEXT NOT NULL, '
            'PRIMARY KEY (table_name, row_id))',
          );
          await db.execute(
            'CREATE TABLE sync_outbox ('
            'local_id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, '
            'entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, '
            'created_at TEXT NOT NULL, status TEXT NOT NULL, last_error TEXT)',
          );
        },
      );
      _sqlite = db;
      await _hydrate(db);
    } catch (e) {
      debugPrint(
          'AppDatabase: no persistent storage available ($e) — using an in-memory store for this session.');
    }
  }

  Future<void> _hydrate(Database db) async {
    for (final row in await db.query('kv_store')) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      _tableFor(row['table_name'] as String)[row['row_id'] as String] = data;
    }
    final outboxRows = await db.query('sync_outbox');
    for (final row in outboxRows) {
      _outbox.add(OutboxJob(
        localId: row['local_id'] as int,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(row['created_at'] as String),
        status: row['status'] as String,
        lastError: row['last_error'] as String?,
      ));
    }
    if (_outbox.isNotEmpty) {
      _nextOutboxId =
          _outbox.map((j) => j.localId).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  Map<String, Map<String, dynamic>> _tableFor(String table) {
    switch (table) {
      case 'products':
        return _products;
      case 'categories':
        return _categories;
      case 'finance_entries':
        return _financeEntries;
      case 'dashboard_cache':
        return _dashboardCache;
      default:
        throw ArgumentError('Unknown local table: $table');
    }
  }

  void _put(String table, String id, Map<String, dynamic> data) {
    _tableFor(table)[id] = data;
    unawaited(_mirrorPut(table, id, data));
  }

  void _remove(String table, String id) {
    _tableFor(table).remove(id);
    unawaited(_mirrorRemove(table, id));
  }

  Future<void> _mirrorPut(
      String table, String id, Map<String, dynamic> data) async {
    final db = _sqlite;
    if (db == null) return;
    try {
      await db.insert(
        'kv_store',
        {'table_name': table, 'row_id': id, 'data': jsonEncode(data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Best-effort mirror only — in-memory state remains the source of
      // truth for this session either way.
    }
  }

  Future<void> _mirrorRemove(String table, String id) async {
    final db = _sqlite;
    if (db == null) return;
    try {
      await db.delete('kv_store',
          where: 'table_name = ? AND row_id = ?', whereArgs: [table, id]);
    } catch (_) {}
  }

  // ---------------- Products ----------------

  Product _productFromRow(Map<String, dynamic> row) => Product(
        id: row['id'] as String,
        categoryId: row['category_id'] as String?,
        categoryName: row['category_name'] as String?,
        name: row['name'] as String,
        sku: row['sku'] as String?,
        price: row['price'] as int,
        costPrice: row['cost_price'] as int,
        isActive: row['is_active'] as bool,
        imageUrl: row['image_url'] as String?,
        hasPhoto: row['has_photo'] as bool? ?? false,
        pendingImagePath: row['pending_image_path'] as String?,
        pendingSync: SyncRowStatus.fromName(row['sync_status'] as String?)
            .isPending,
      );

  Map<String, dynamic> _productToRow(Product product, SyncRowStatus status) =>
      {
        'id': product.id,
        'category_id': product.categoryId,
        'category_name': product.categoryName,
        'name': product.name,
        'sku': product.sku,
        'price': product.price,
        'cost_price': product.costPrice,
        'is_active': product.isActive,
        'image_url': product.imageUrl,
        'has_photo': product.hasPhoto,
        'pending_image_path': product.pendingImagePath,
        'sync_status': status.name,
      };

  List<Product> getProducts() => _products.values
      .where((r) =>
          SyncRowStatus.fromName(r['sync_status'] as String?) !=
          SyncRowStatus.pendingDelete)
      .map(_productFromRow)
      .toList();

  /// Applies a fresh server list — never overwrites a row that has unsynced
  /// local changes (that row wins until it syncs), and drops rows the
  /// server no longer returns as long as they aren't pending locally.
  void mergeProductsFromServer(List<Product> products) {
    final seen = <String>{};
    for (final product in products) {
      seen.add(product.id);
      final existingRow = _products[product.id];
      final status = _statusOf(existingRow);
      if (status != SyncRowStatus.synced) continue;
      // Don't let a background refresh wipe out a photo still queued for
      // upload — the server response here predates that upload finishing.
      final pendingImagePath = existingRow == null
          ? null
          : _productFromRow(existingRow).pendingImagePath;
      final merged = pendingImagePath == null
          ? product
          : product.copyWith(pendingImagePath: pendingImagePath);
      _put('products', product.id, _productToRow(merged, SyncRowStatus.synced));
    }
    for (final id in _products.keys.toList()) {
      if (seen.contains(id)) continue;
      if (_statusOf(_products[id]) == SyncRowStatus.synced) {
        _remove('products', id);
      }
    }
  }

  void putLocalProduct(Product product, SyncRowStatus status) =>
      _put('products', product.id, _productToRow(product, status));

  /// Replaces a locally-created row (temp id) with the server's canonical
  /// row once the create syncs successfully.
  void markProductSynced(Product canonical, {String? replacesLocalId}) {
    if (replacesLocalId != null && replacesLocalId != canonical.id) {
      _remove('products', replacesLocalId);
    }
    _put(
        'products', canonical.id, _productToRow(canonical, SyncRowStatus.synced));
  }

  void removeProduct(String id) => _remove('products', id);

  /// Single-row lookup by id, including a row pending deletion — used by
  /// the photo-upload queue to read/update a row without going through the
  /// list-filtering [getProducts].
  Product? findProduct(String id) {
    final row = _products[id];
    return row == null ? null : _productFromRow(row);
  }

  SyncRowStatus productStatus(String id) => _statusOf(_products[id]);

  // ---------------- Categories ----------------

  ProductCategory _categoryFromRow(Map<String, dynamic> row) =>
      ProductCategory(id: row['id'] as String, name: row['name'] as String);

  Map<String, dynamic> _categoryToRow(
          ProductCategory category, SyncRowStatus status) =>
      {'id': category.id, 'name': category.name, 'sync_status': status.name};

  List<ProductCategory> getCategories() =>
      _categories.values.map(_categoryFromRow).toList();

  void mergeCategoriesFromServer(List<ProductCategory> categories) {
    for (final category in categories) {
      final status = _statusOf(_categories[category.id]);
      if (status != SyncRowStatus.synced) continue;
      _put('categories', category.id,
          _categoryToRow(category, SyncRowStatus.synced));
    }
  }

  void putLocalCategory(ProductCategory category, SyncRowStatus status) =>
      _put('categories', category.id, _categoryToRow(category, status));

  void markCategorySynced(ProductCategory canonical, {String? replacesLocalId}) {
    if (replacesLocalId != null && replacesLocalId != canonical.id) {
      _remove('categories', replacesLocalId);
    }
    _put('categories', canonical.id,
        _categoryToRow(canonical, SyncRowStatus.synced));
  }

  // ---------------- Finance entries ----------------

  FinanceEntry _financeFromRow(Map<String, dynamic> row) => FinanceEntry(
        id: row['id'] as String,
        type: row['type'] as String,
        amount: row['amount'] as int,
        category: row['category'] as String,
        note: row['note'] as String?,
        occurredAt: DateTime.parse(row['occurred_at'] as String),
        businessId: row['business_id'] as String?,
        businessName: row['business_name'] as String?,
        sourceType: row['source_type'] as String?,
        sourceId: row['source_id'] as String?,
        pendingSync: SyncRowStatus.fromName(row['sync_status'] as String?)
            .isPending,
      );

  Map<String, dynamic> _financeToRow(FinanceEntry entry, SyncRowStatus status) =>
      {
        'id': entry.id,
        'type': entry.type,
        'amount': entry.amount,
        'category': entry.category,
        'note': entry.note,
        'occurred_at': entry.occurredAt.toIso8601String(),
        'business_id': entry.businessId,
        'business_name': entry.businessName,
        'source_type': entry.sourceType,
        'source_id': entry.sourceId,
        'sync_status': status.name,
      };

  List<FinanceEntry> getFinanceEntries() => _financeEntries.values
      .where((r) =>
          SyncRowStatus.fromName(r['sync_status'] as String?) !=
          SyncRowStatus.pendingDelete)
      .map(_financeFromRow)
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  void mergeFinanceEntriesFromServer(List<FinanceEntry> entries) {
    for (final entry in entries) {
      final status = _statusOf(_financeEntries[entry.id]);
      if (status != SyncRowStatus.synced) continue;
      _put('finance_entries', entry.id,
          _financeToRow(entry, SyncRowStatus.synced));
    }
  }

  void putLocalFinanceEntry(FinanceEntry entry, SyncRowStatus status) =>
      _put('finance_entries', entry.id, _financeToRow(entry, status));

  void markFinanceEntrySynced(FinanceEntry canonical, {String? replacesLocalId}) {
    if (replacesLocalId != null && replacesLocalId != canonical.id) {
      _remove('finance_entries', replacesLocalId);
    }
    _put('finance_entries', canonical.id,
        _financeToRow(canonical, SyncRowStatus.synced));
  }

  void removeFinanceEntry(String id) => _remove('finance_entries', id);

  // ---------------- Dashboard cache ----------------

  Map<String, dynamic>? getDashboardCache(String businessId) =>
      _dashboardCache[businessId];

  void putDashboardCache(String businessId, Map<String, dynamic> data) =>
      _put('dashboard_cache', businessId, data);

  // ---------------- Outbox ----------------

  SyncRowStatus _statusOf(Map<String, dynamic>? row) =>
      row == null ? SyncRowStatus.synced : SyncRowStatus.fromName(row['sync_status'] as String?);

  int pendingCountFor(String? entityType) => _outbox
      .where((j) =>
          j.status == 'pending' &&
          (entityType == null || j.entityType == entityType))
      .length;

  int get pendingCount => pendingCountFor(null);

  int get failedCount => _outbox.where((j) => j.status == 'failed').length;

  List<OutboxJob> pendingJobs(String entityType) => _outbox
      .where((j) => j.entityType == entityType && j.status == 'pending')
      .toList();

  List<OutboxJob> get failedJobs =>
      _outbox.where((j) => j.status == 'failed').toList();

  /// If a pending `create`/`update` job for [entityId] already exists, its
  /// payload is replaced in place instead of queuing a second job — avoids
  /// double-submitting a row edited twice before the first sync attempt.
  OutboxJob enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    if (operation != 'delete') {
      final existing = _outbox
          .where((j) =>
              j.entityType == entityType &&
              j.entityId == entityId &&
              j.status == 'pending')
          .firstOrNull;
      if (existing != null) {
        existing.payload
          ..clear()
          ..addAll(payload);
        unawaited(_mirrorOutbox(existing));
        return existing;
      }
    }
    final job = OutboxJob(
      localId: _nextOutboxId++,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: DateTime.now(),
    );
    _outbox.add(job);
    unawaited(_mirrorOutbox(job));
    return job;
  }

  void markSynced(int localId) {
    _outbox.removeWhere((j) => j.localId == localId);
    unawaited(_mirrorOutboxDelete(localId));
  }

  void markFailed(int localId, String error) {
    final job = _outbox.where((j) => j.localId == localId).firstOrNull;
    if (job == null) return;
    job.status = 'failed';
    job.lastError = error;
    unawaited(_mirrorOutbox(job));
  }

  void discardJob(int localId) {
    _outbox.removeWhere((j) => j.localId == localId);
    unawaited(_mirrorOutboxDelete(localId));
  }

  /// Drops every outbox job for [entityId] — used when a locally-created
  /// row (never reached the server) is deleted before it ever synced.
  void discardPendingJobsFor(String entityType, String entityId) {
    final toRemove =
        _outbox.where((j) => j.entityType == entityType && j.entityId == entityId).toList();
    for (final job in toRemove) {
      _outbox.remove(job);
      unawaited(_mirrorOutboxDelete(job.localId));
    }
  }

  Future<void> _mirrorOutbox(OutboxJob job) async {
    final db = _sqlite;
    if (db == null) return;
    try {
      await db.insert(
        'sync_outbox',
        {
          'local_id': job.localId,
          'entity_type': job.entityType,
          'entity_id': job.entityId,
          'operation': job.operation,
          'payload': jsonEncode(job.payload),
          'created_at': job.createdAt.toIso8601String(),
          'status': job.status,
          'last_error': job.lastError,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _mirrorOutboxDelete(int localId) async {
    final db = _sqlite;
    if (db == null) return;
    try {
      await db.delete('sync_outbox', where: 'local_id = ?', whereArgs: [localId]);
    } catch (_) {}
  }
}
