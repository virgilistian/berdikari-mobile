import 'dart:async';

import 'package:flutter/foundation.dart';

import '../local/app_database.dart';
import '../local/sync/sync_status.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/client_uuid.dart';

/// Products + categories — local-first: [AppDatabase] is the source of
/// truth for every read, writes land there immediately (optimistic UI) and
/// are queued in the outbox for background sync via [pushPending].
///
/// [load] returns active-only products (for the POS grid); [loadAll]
/// returns every product including inactive ones (for the Catalog
/// management screen, which needs to toggle/edit them). The very first
/// call bootstraps the local store from the network if it's still empty;
/// after that, reads never block on the network — call [pullRefresh]
/// (or `load(refresh: true)`) explicitly to fetch fresh data.
class CatalogRepository extends ChangeNotifier {
  CatalogRepository({
    required CatalogService catalogService,
    required AppDatabase database,
  })  : _catalog = catalogService,
        _db = database;

  final CatalogService _catalog;
  final AppDatabase _db;
  bool _bootstrapped = false;
  bool _pushing = false;

  int get pendingCount =>
      _db.pendingCountFor('product') + _db.pendingCountFor('category');

  Future<void> _ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    if (_db.getProducts().isEmpty && _db.getCategories().isEmpty) {
      await pullRefresh();
    }
  }

  Future<(List<Product>, List<ProductCategory>)> load(
      {bool refresh = false}) async {
    await _ensureBootstrapped();
    if (refresh) await pullRefresh();
    final products = _db.getProducts().where((p) => p.isActive).toList();
    return (products, _db.getCategories());
  }

  Future<(List<Product>, List<ProductCategory>)> loadAll(
      {bool refresh = false}) async {
    await _ensureBootstrapped();
    if (refresh) await pullRefresh();
    return (_db.getProducts(), _db.getCategories());
  }

  /// Fetches fresh products/categories from the API and merges them into
  /// the local store. Never overwrites a row with unsynced local edits.
  /// Failures (offline, server error) are swallowed — whatever's already
  /// cached locally keeps serving the UI.
  Future<void> pullRefresh() async {
    try {
      final results =
          await Future.wait([_catalog.fetchProducts(), _catalog.fetchCategories()]);
      _db.mergeProductsFromServer(results[0] as List<Product>);
      _db.mergeCategoriesFromServer(results[1] as List<ProductCategory>);
      notifyListeners();
    } catch (_) {
      // Offline or server error — local cache is still valid.
    }
  }

  Future<Product> saveProduct({
    String? id,
    required String name,
    required String? categoryId,
    required int price,
    required int costPrice,
    String? sku,
    required bool isActive,
  }) async {
    await _ensureBootstrapped();
    final categoryName = _db
        .getCategories()
        .where((c) => c.id == categoryId)
        .map((c) => c.name)
        .firstOrNull;
    final isCreate = id == null;
    final localId = id ?? 'local-${generateClientUuid()}';
    final product = Product(
      id: localId,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      sku: sku,
      price: price,
      costPrice: costPrice,
      isActive: isActive,
      imageUrl: null,
      pendingSync: true,
    );
    _db.putLocalProduct(
        product, isCreate ? SyncRowStatus.pendingCreate : SyncRowStatus.pendingUpdate);
    _db.enqueue(
      entityType: 'product',
      entityId: localId,
      operation: isCreate ? 'create' : 'update',
      payload: {
        'name': name,
        'category_id': categoryId,
        'price': price,
        'cost_price': costPrice,
        'sku': sku,
        'is_active': isActive,
      },
    );
    notifyListeners();
    unawaited(pushPending());
    return product;
  }

  Future<void> deleteProduct(String id) async {
    await _ensureBootstrapped();
    if (id.startsWith('local-')) {
      // Never reached the server — nothing to sync, just drop it.
      _db.discardPendingJobsFor('product', id);
      _db.removeProduct(id);
    } else {
      final current = _db.getProducts().where((p) => p.id == id).firstOrNull;
      if (current != null) {
        _db.putLocalProduct(current, SyncRowStatus.pendingDelete);
      }
      _db.enqueue(
        entityType: 'product',
        entityId: id,
        operation: 'delete',
        payload: const {},
      );
    }
    notifyListeners();
    unawaited(pushPending());
  }

  Future<ProductCategory> createCategory(String name) async {
    await _ensureBootstrapped();
    final localId = 'local-${generateClientUuid()}';
    final category = ProductCategory(id: localId, name: name);
    _db.putLocalCategory(category, SyncRowStatus.pendingCreate);
    _db.enqueue(
      entityType: 'category',
      entityId: localId,
      operation: 'create',
      payload: {'name': name},
    );
    notifyListeners();
    unawaited(pushPending());
    return category;
  }

  /// Drains the outbox: categories first (products may reference a
  /// still-unsynced category by its local id), then products. Stops at the
  /// first network-level failure (leaves the rest queued for the next
  /// sync pass); a server rejection marks just that job `failed` and
  /// continues with the rest — same shape as `OfflineQueueRepository`.
  Future<void> pushPending() async {
    if (_pushing) return;
    _pushing = true;
    try {
      await _pushCategories();
      await _pushProducts();
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushCategories() async {
    for (final job in _db.pendingJobs('category')) {
      try {
        final saved = await _catalog.createCategory(job.payload['name'] as String);
        _db.markCategorySynced(saved, replacesLocalId: job.entityId);
        _remapPendingProductCategory(oldId: job.entityId, newId: saved.id);
        _db.markSynced(job.localId);
        notifyListeners();
      } on ApiException catch (e) {
        _db.markFailed(job.localId, e.message);
        notifyListeners();
      } catch (_) {
        break; // network-level failure — retry on the next sync pass.
      }
    }
  }

  void _remapPendingProductCategory({required String oldId, required String newId}) {
    for (final job in _db.pendingJobs('product')) {
      if (job.payload['category_id'] == oldId) {
        job.payload['category_id'] = newId;
      }
    }
  }

  Future<void> _pushProducts() async {
    for (final job in _db.pendingJobs('product')) {
      try {
        if (job.operation == 'delete') {
          await _catalog.deleteProduct(job.entityId);
          _db.removeProduct(job.entityId);
        } else {
          final saved = await _catalog.saveProduct(
            id: job.operation == 'update' ? job.entityId : null,
            name: job.payload['name'] as String,
            categoryId: job.payload['category_id'] as String?,
            price: job.payload['price'] as int,
            costPrice: job.payload['cost_price'] as int,
            sku: job.payload['sku'] as String?,
            isActive: job.payload['is_active'] as bool,
          );
          _db.markProductSynced(saved, replacesLocalId: job.entityId);
        }
        _db.markSynced(job.localId);
        notifyListeners();
      } on ApiException catch (e) {
        _db.markFailed(job.localId, e.message);
        notifyListeners();
      } catch (_) {
        break; // network-level failure — retry on the next sync pass.
      }
    }
  }
}
