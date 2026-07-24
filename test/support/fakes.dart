import 'package:berdikari_mobile/data/local/pending_order_store.dart';
import 'package:berdikari_mobile/data/models/auth_user.dart';
import 'package:berdikari_mobile/data/models/daily_stock.dart';
import 'package:berdikari_mobile/data/models/finance.dart';
import 'package:berdikari_mobile/data/models/order.dart';
import 'package:berdikari_mobile/data/models/pending_order.dart';
import 'package:berdikari_mobile/data/models/product.dart';
import 'package:berdikari_mobile/data/models/sales_summary.dart';
import 'package:berdikari_mobile/data/models/shift.dart';
import 'package:berdikari_mobile/data/models/stock.dart';
import 'package:berdikari_mobile/data/repositories/auth_repository.dart';
import 'package:berdikari_mobile/data/repositories/daily_stock_repository.dart';
import 'package:berdikari_mobile/data/services/api_client.dart';
import 'package:berdikari_mobile/data/services/auth_service.dart';
import 'package:berdikari_mobile/data/services/catalog_service.dart';
import 'package:berdikari_mobile/data/services/finance_service.dart';
import 'package:berdikari_mobile/data/services/inventory_service.dart';
import 'package:berdikari_mobile/data/services/sales_service.dart';
import 'package:berdikari_mobile/data/services/token_storage.dart';

/// Token storage backed by a plain field — no platform channel.
class InMemoryTokenStorage extends TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// AuthService that answers from fixtures instead of HTTP.
class FakeAuthService extends AuthService {
  FakeAuthService({this.user, this.token = 'fake-token', this.loginError})
      : super(apiClient: ApiClient(tokenProvider: () async => null));

  AuthUser? user;
  String token;
  ApiException? loginError;
  bool logoutCalled = false;

  @override
  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final error = loginError;
    if (error != null) throw error;
    return (token: token, user: user!);
  }

  @override
  Future<AuthUser> me() async {
    final current = user;
    if (current == null) {
      throw ApiException(statusCode: 401, message: 'Unauthenticated.');
    }
    return current;
  }

  @override
  Future<void> logout() async => logoutCalled = true;

  @override
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final current = user!;
    user = AuthUser(
      id: current.id,
      name: name,
      email: email,
      role: current.role,
      businessId: current.businessId,
      roles: current.roles,
      permissions: current.permissions,
    );
    return user!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}
}

AuthUser sampleUser({
  List<String> permissions = const ['finance.view', 'pos.view', 'pos.open'],
  List<String> roles = const ['cashier'],
  String name = 'Ibu Sari',
}) =>
    AuthUser(
      id: '1',
      name: name,
      email: 'sari@berdikari.id',
      role: 'cashier',
      businessId: '1',
      roles: roles,
      permissions: permissions,
    );

/// Repository wired to fakes. Seed [token] to simulate a persisted session.
AuthRepository fakeAuthRepository({
  AuthUser? user,
  String? token,
  ApiException? loginError,
}) =>
    AuthRepository(
      service: FakeAuthService(user: user, loginError: loginError),
      tokenStorage: InMemoryTokenStorage(token),
    );

Product sampleProduct({
  String id = 'p1',
  String name = 'Es Teh',
  int price = 5000,
  int costPrice = 2000,
  String? categoryId = 'c1',
  String? categoryName = 'Minuman',
  bool isActive = true,
}) =>
    Product(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      sku: null,
      price: price,
      costPrice: costPrice,
      isActive: isActive,
      imageUrl: null,
    );

/// CatalogService that answers from in-memory fixtures instead of HTTP.
/// Mutating calls (save/delete/createCategory) act on these lists directly,
/// like a tiny in-memory backend, so repository/view-model tests can assert
/// on the resulting state without mocking HTTP.
class FakeCatalogService extends CatalogService {
  FakeCatalogService({List<Product>? products, List<ProductCategory>? categories})
      : products = products ??
            [
              sampleProduct(id: 'p1', name: 'Es Teh', price: 5000),
              sampleProduct(id: 'p2', name: 'Nasi Kucing', price: 3000),
            ],
        categories = categories ?? [const ProductCategory(id: 'c1', name: 'Minuman')],
        super(apiClient: ApiClient(tokenProvider: () async => null));

  List<Product> products;
  List<ProductCategory> categories;
  ApiException? saveError;
  int _nextId = 100;

  @override
  Future<List<Product>> fetchProducts() async => products;

  @override
  Future<List<ProductCategory>> fetchCategories() async => categories;

  @override
  Future<Product> saveProduct({
    String? id,
    required String name,
    required String? categoryId,
    required int price,
    required int costPrice,
    String? sku,
    required bool isActive,
  }) async {
    final error = saveError;
    if (error != null) throw error;

    final categoryName = categories
        .where((c) => c.id == categoryId)
        .map((c) => c.name)
        .firstOrNull;
    final saved = Product(
      id: id ?? 'p${_nextId++}',
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      sku: sku,
      price: price,
      costPrice: costPrice,
      isActive: isActive,
      imageUrl: null,
    );
    products = [
      for (final p in products)
        if (p.id != saved.id) p,
      saved,
    ];
    return saved;
  }

  @override
  Future<void> deleteProduct(String id) async {
    products = products.where((p) => p.id != id).toList();
  }

  @override
  Future<ProductCategory> createCategory(String name) async {
    final category = ProductCategory(id: 'c${_nextId++}', name: name);
    categories = [...categories, category];
    return category;
  }
}

/// InventoryService that answers from in-memory fixtures instead of HTTP.
class FakeInventoryService extends InventoryService {
  FakeInventoryService({
    List<DailyStockItem>? todayStock,
    List<ProductForStock>? stockProducts,
    List<StockRow>? stockRows,
    StockSummary? summary,
    List<StockMovement>? movements,
    List<StockRow>? lowStock,
  })  : todayStock = todayStock ?? [],
        stockProducts = stockProducts ?? [],
        stockRows = stockRows ?? [],
        summary = summary ??
            const StockSummary(
              totalProducts: 0,
              stockValue: 0,
              retailValue: 0,
              lowStockCount: 0,
            ),
        movements = movements ?? [],
        lowStock = lowStock ?? [],
        super(apiClient: ApiClient(tokenProvider: () async => null));

  List<DailyStockItem> todayStock;
  List<ProductForStock> stockProducts;
  List<StockRow> stockRows;
  StockSummary summary;
  List<StockMovement> movements;
  List<StockRow> lowStock;
  Map<String, dynamic>? lastOpenPayload;
  Map<String, dynamic>? lastReceivePayload;
  Map<String, dynamic>? lastAdjustPayload;
  Map<String, dynamic>? lastMinStockPayload;

  @override
  Future<List<StockRow>> fetchLowStock({String? businessId}) async => lowStock;

  @override
  Future<List<DailyStockItem>> fetchTodayStock({String? businessId}) async =>
      todayStock;

  @override
  Future<List<ProductForStock>> fetchStockProducts({String? businessId}) async =>
      stockProducts;

  @override
  Future<List<DailyStockItem>> openDay({
    String? businessId,
    required List<({String productId, String productName, int openingQty})>
        items,
  }) async {
    lastOpenPayload = {'business_id': businessId, 'items': items};
    todayStock = [
      for (final item in items)
        DailyStockItem(
          id: 'ds-${item.productId}',
          productId: item.productId,
          productName: item.productName,
          price: null,
          imageUrl: null,
          openingQty: item.openingQty,
          adjustmentQty: 0,
          adjustmentNote: null,
          soldQty: 0,
          closingQty: null,
          status: 'open',
        ),
    ];
    return todayStock;
  }

  @override
  Future<List<DailyStockItem>> openDayFor({
    String? businessId,
    required String date,
    required List<({String productId, String productName, int openingQty})>
        items,
  }) async {
    lastOpenPayload = {'business_id': businessId, 'date': date, 'items': items};
    final result = [
      for (final item in items)
        DailyStockItem(
          id: 'ds-${item.productId}',
          productId: item.productId,
          productName: item.productName,
          price: null,
          imageUrl: null,
          openingQty: item.openingQty,
          adjustmentQty: 0,
          adjustmentNote: null,
          soldQty: 0,
          closingQty: null,
          status: date == DailyStockRepository.today ? 'open' : 'draft',
        ),
    ];
    if (date == DailyStockRepository.today) todayStock = result;
    return result;
  }

  @override
  Future<List<DailyStockItem>> closeDay({String? businessId}) async {
    todayStock = [
      for (final item in todayStock)
        DailyStockItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          imageUrl: item.imageUrl,
          openingQty: item.openingQty,
          adjustmentQty: item.adjustmentQty,
          adjustmentNote: item.adjustmentNote,
          soldQty: item.soldQty,
          closingQty: item.remainingQty,
          status: 'closed',
        ),
    ];
    return todayStock;
  }

  List<DailyStockHistoryRow> history = [];
  Map<String, List<DailyStockItem>> dayDetails = {};
  Map<String, dynamic>? lastAdjustDailyStockPayload;
  String? lastDeletedDate;

  @override
  Future<List<DailyStockHistoryRow>> fetchHistory({String? businessId}) async =>
      history;

  @override
  Future<List<DailyStockItem>> fetchDayDetail({
    String? businessId,
    required String date,
  }) async =>
      dayDetails[date] ?? const [];

  @override
  Future<DailyStockItem> adjustDailyStock({
    String? businessId,
    required String date,
    required String productId,
    required int adjustmentQty,
    String? adjustmentNote,
  }) async {
    lastAdjustDailyStockPayload = {
      'date': date,
      'product_id': productId,
      'adjustment_qty': adjustmentQty,
      'adjustment_note': adjustmentNote,
    };
    final existing = todayStock.firstWhere((s) => s.productId == productId);
    final updated = DailyStockItem(
      id: existing.id,
      productId: existing.productId,
      productName: existing.productName,
      price: existing.price,
      imageUrl: existing.imageUrl,
      openingQty: existing.openingQty,
      adjustmentQty: existing.adjustmentQty + adjustmentQty,
      adjustmentNote: adjustmentNote,
      soldQty: existing.soldQty,
      closingQty: existing.closingQty,
      status: existing.status,
    );
    todayStock = [
      for (final s in todayStock)
        if (s.productId == productId) updated else s,
    ];
    return updated;
  }

  @override
  Future<void> deleteDailyStockDay({String? businessId, required String date}) async {
    lastDeletedDate = date;
  }

  @override
  Future<(List<StockRow>, StockSummary)> fetchStock({String? businessId}) async =>
      (stockRows, summary);

  @override
  Future<void> receive({
    String? businessId,
    required String productId,
    required int quantity,
    String? reason,
  }) async {
    lastReceivePayload = {
      'product_id': productId,
      'quantity': quantity,
      'reason': reason,
    };
    stockRows = [
      for (final row in stockRows)
        if (row.productId == productId)
          StockRow(
            productId: row.productId,
            productName: row.productName,
            quantity: row.quantity + quantity,
            minStock: row.minStock,
            purchasePrice: row.purchasePrice,
            stockValue: row.stockValue,
            isLow: (row.quantity + quantity) < row.minStock,
          )
        else
          row,
    ];
  }

  @override
  Future<void> adjust({
    String? businessId,
    required String productId,
    required int quantity,
    String? reason,
  }) async {
    lastAdjustPayload = {
      'product_id': productId,
      'quantity': quantity,
      'reason': reason,
    };
    stockRows = [
      for (final row in stockRows)
        if (row.productId == productId)
          StockRow(
            productId: row.productId,
            productName: row.productName,
            quantity: quantity,
            minStock: row.minStock,
            purchasePrice: row.purchasePrice,
            stockValue: row.stockValue,
            isLow: quantity < row.minStock,
          )
        else
          row,
    ];
  }

  @override
  Future<void> setMinStock({
    String? businessId,
    required String productId,
    required int minStock,
  }) async {
    lastMinStockPayload = {'product_id': productId, 'min_stock': minStock};
    stockRows = [
      for (final row in stockRows)
        if (row.productId == productId)
          StockRow(
            productId: row.productId,
            productName: row.productName,
            quantity: row.quantity,
            minStock: minStock,
            purchasePrice: row.purchasePrice,
            stockValue: row.stockValue,
            isLow: row.quantity < minStock,
          )
        else
          row,
    ];
  }

  @override
  Future<List<StockMovement>> fetchMovements({
    String? businessId,
    required String productId,
  }) async =>
      movements;
}

StockRow sampleStockRow({
  String productId = 'p1',
  String productName = 'Es Teh',
  int quantity = 20,
  int minStock = 5,
  int purchasePrice = 2000,
  int? stockValue,
  bool? isLow,
}) =>
    StockRow(
      productId: productId,
      productName: productName,
      quantity: quantity,
      minStock: minStock,
      purchasePrice: purchasePrice,
      stockValue: stockValue ?? purchasePrice * quantity,
      isLow: isLow ?? quantity < minStock,
    );

/// In-memory pending-order queue store — no `shared_preferences` platform
/// channel, which can hang (rather than cleanly throw) under
/// `TestWidgetsFlutterBinding` in this environment.
class FakePendingOrderStore extends PendingOrderStore {
  List<PendingOrder> _orders = [];

  @override
  Future<List<PendingOrder>> load() async => _orders;

  @override
  Future<void> save(List<PendingOrder> orders) async => _orders = orders;
}

/// SalesService that answers from fixtures instead of HTTP.
class FakeSalesService extends SalesService {
  FakeSalesService({
    this.activeShift,
    this.orders = const [],
    this.checkoutError,
  }) : super(apiClient: ApiClient(tokenProvider: () async => null));

  CashierShift? activeShift;
  List<Order> orders;
  ApiException? checkoutError;
  Map<String, dynamic>? lastCheckoutPayload;

  /// When true, every [submitOrder] throws a plain (non-[ApiException])
  /// error — simulates a persistent network failure, which
  /// [OfflineQueueRepository.drain] treats as "still offline" and leaves
  /// the order queued (never marked failed) no matter how many times it
  /// retries.
  bool alwaysThrowNetworkError = false;

  @override
  Future<Order> submitOrder(Map<String, dynamic> payload) async {
    lastCheckoutPayload = payload;
    if (alwaysThrowNetworkError) {
      throw Exception('network down');
    }
    final error = checkoutError;
    if (error != null) throw error;

    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    final total = items.fold<int>(
        0, (sum, i) => sum + (i['quantity'] as int) * (i['unit_price'] as int));
    final payments =
        (payload['payments'] as List).cast<Map<String, dynamic>>();
    final paid =
        payments.fold<int>(0, (sum, p) => sum + (p['amount'] as int));

    return Order(
      id: payload['client_uuid'] as String,
      orderNo: 'INV-0001',
      status: 'completed',
      paymentStatus: paid >= total ? 'paid' : 'partial',
      totalAmount: total,
      paidAmount: paid,
      changeAmount: (paid - total).clamp(0, paid),
      balanceDue: (total - paid).clamp(0, total),
      customerName: payload['customer_name'] as String?,
      createdAt: DateTime.now(),
      items: const [],
      payments: const [],
    );
  }

  @override
  Future<List<Order>> fetchOrders({
    String? businessId,
    String? status,
    String? date,
  }) async {
    var result = orders;
    if (status != null && status.isNotEmpty) {
      result = result.where((o) => o.status == status).toList();
    }
    if (date != null) {
      result = result
          .where((o) => o.createdAt.toIso8601String().split('T').first == date)
          .toList();
    }
    return result;
  }

  SalesSummary summary = SalesSummary.empty;

  @override
  Future<SalesSummary> fetchSummary({
    String? businessId,
    String? from,
    String? to,
  }) async =>
      summary;

  @override
  Future<CashierShift?> fetchActiveShift() async => activeShift;

  @override
  Future<CashierShift> openShift({required int openingCash}) async {
    activeShift = sampleShift(openingCash: openingCash);
    return activeShift!;
  }

  @override
  Future<CashierShift> closeShift(
    String id, {
    required int closingCash,
    String? closingNote,
  }) async {
    final closed = sampleShift(
      id: id,
      status: 'closed',
      openingCash: activeShift?.openingCash ?? 0,
      closingCash: closingCash,
      expectedCash: activeShift?.openingCash ?? 0,
      cashDifference:
          closingCash - (activeShift?.openingCash ?? 0),
      closingNote: closingNote,
    );
    activeShift = null;
    return closed;
  }
}

CashierShift sampleShift({
  String id = 's1',
  String status = 'open',
  int openingCash = 100000,
  int? closingCash,
  int? expectedCash,
  int? cashDifference,
  int transactionCount = 0,
  int totalItemsSold = 0,
  int totalSales = 0,
  int totalExpenses = 0,
  int? netIncome,
  String? closingNote,
  List<ShiftStockSummaryItem> stockSummary = const [],
}) =>
    CashierShift(
      id: id,
      status: status,
      openingCash: openingCash,
      closingCash: closingCash,
      expectedCash: expectedCash,
      cashDifference: cashDifference,
      transactionCount: transactionCount,
      totalItemsSold: totalItemsSold,
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      netIncome: netIncome,
      closingNote: closingNote,
      openedAt: DateTime.now(),
      closedAt: status == 'closed' ? DateTime.now() : null,
      cashierName: 'Ibu Sari',
      stockSummary: stockSummary,
    );

/// FinanceService that answers from in-memory fixtures instead of HTTP.
class FakeFinanceService extends FinanceService {
  FakeFinanceService({List<FinanceEntry>? entries, FinanceSummary? summary})
      : entries = entries ?? [],
        summary = summary ?? FinanceSummary.empty,
        super(apiClient: ApiClient(tokenProvider: () async => null));

  List<FinanceEntry> entries;
  FinanceSummary summary;
  int _nextId = 100;
  Map<String, dynamic>? lastCreatePayload;
  Map<String, dynamic>? lastUpdatePayload;

  /// When true, [createEntry] throws a plain (non-[ApiException]) error —
  /// simulates a network-level failure so the outbox job stays `pending`.
  bool failCreate = false;

  @override
  Future<List<FinanceEntry>> fetchEntries({
    String? businessId,
    String? type,
    String? category,
    String? from,
    String? to,
  }) async {
    if (type == null || type.isEmpty) return entries;
    return entries.where((e) => e.type == type).toList();
  }

  @override
  Future<FinanceSummary> fetchSummary({
    String? businessId,
    String? from,
    String? to,
  }) async =>
      summary;

  @override
  Future<FinanceEntry> createEntry({
    String? businessId,
    required String type,
    required int amount,
    required String category,
    String? note,
    String? occurredAt,
    String? shiftId,
    String? clientUuid,
  }) async {
    if (failCreate) throw Exception('network error');
    lastCreatePayload = {
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'occurred_at': occurredAt,
      'shift_id': shiftId,
      'client_uuid': clientUuid,
    };
    final entry = FinanceEntry(
      id: 'f${_nextId++}',
      type: type,
      amount: amount,
      category: category,
      note: note,
      occurredAt: occurredAt != null ? DateTime.parse(occurredAt) : DateTime.now(),
      sourceType: shiftId != null ? 'shift_expense' : 'manual',
      sourceId: shiftId,
    );
    entries = [...entries, entry];
    return entry;
  }

  @override
  Future<FinanceEntry> updateEntry(
    String id, {
    required String type,
    required int amount,
    required String category,
    String? note,
    String? occurredAt,
  }) async {
    lastUpdatePayload = {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'occurred_at': occurredAt,
    };
    final current = entries.firstWhere((e) => e.id == id);
    final updated = FinanceEntry(
      id: id,
      type: type,
      amount: amount,
      category: category,
      note: note,
      occurredAt: occurredAt != null ? DateTime.parse(occurredAt) : current.occurredAt,
      sourceType: current.sourceType,
      sourceId: current.sourceId,
    );
    entries = [for (final e in entries) e.id == id ? updated : e];
    return updated;
  }

  @override
  Future<List<FinanceEntry>> fetchShiftExpenses(String shiftId) async =>
      entries.where((e) => e.sourceType == 'shift_expense' && e.sourceId == shiftId).toList();

  @override
  Future<void> deleteEntry(String id) async {
    entries = entries.where((e) => e.id != id).toList();
  }
}

FinanceEntry sampleFinanceEntry({
  String id = 'f1',
  String type = 'expense',
  int amount = 20000,
  String category = 'Belanja Bahan',
  String? note,
  DateTime? occurredAt,
}) =>
    FinanceEntry(
      id: id,
      type: type,
      amount: amount,
      category: category,
      note: note,
      occurredAt: occurredAt ?? DateTime.now(),
    );
